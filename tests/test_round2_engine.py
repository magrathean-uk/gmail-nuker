"""Round 2 engine checks: paging, concurrency, list/unblock/offenders and the launcher allow-list. Mocked Gmail only."""
import argparse
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('gmail_engine', str(ROOT / 'bin/gmail-block'))
spec = importlib.util.spec_from_loader(loader.name, loader)
engine = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = engine
loader.exec_module(engine)
spec = importlib.util.spec_from_file_location('app_launcher_r2', ROOT / 'app/engine_launcher.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

USER = 'owner@example.test'


def forbidden(*a, **k):
    raise AssertionError('network access attempted')


def run(fn, **kwargs):
    args = argparse.Namespace(sa='x', user=USER, json=True, **kwargs)
    out = io.StringIO()
    with patch.object(engine, 'get_sa_token', return_value=('t', True)), \
         patch.object(engine.urllib.request, 'urlopen', side_effect=forbidden), \
         contextlib.redirect_stdout(out):
        code = fn(args)
    text = out.getvalue().strip()
    return code, json.loads(text) if text.startswith('{') else text


def meta(sender, subject='s', unsub=False):
    headers = [{'name': 'From', 'value': sender}, {'name': 'Subject', 'value': subject}]
    if unsub:
        headers.append({'name': 'List-Unsubscribe', 'value': '<mailto:u@x>'})
    return {'threadId': 't', 'payload': {'headers': headers}, 'labelIds': []}


class Paging(unittest.TestCase):
    def pager(self, total, page=500):
        ids = [f'm{i}' for i in range(total)]
        calls = []

        def api(token, path, method='GET', body=None, **kw):
            calls.append(path)
            if 'pageToken=' in path:
                start = int(path.split('pageToken=')[1])
            else:
                start = 0
            chunk = ids[start:start + page]
            res = {'messages': [{'id': i} for i in chunk]}
            if start + page < total:
                res['nextPageToken'] = str(start + page)
            return res
        return ids, calls, api

    def test_pages_across_tokens_to_cap(self):
        ids, calls, api = self.pager(1200)
        with patch.object(engine, 'api_call', side_effect=api):
            got, truncated = engine.list_message_ids('t', 'from:a', 5000)
        self.assertEqual(got, ids)
        self.assertFalse(truncated)
        self.assertEqual(len(calls), 3)

    def test_truncated_when_cap_hit_and_more_exist(self):
        ids, _, api = self.pager(1200)
        with patch.object(engine, 'api_call', side_effect=api):
            got, truncated = engine.list_message_ids('t', 'q', 1000)
        self.assertEqual(got, ids[:1000])
        self.assertTrue(truncated)

    def test_exact_cap_without_more_is_not_truncated(self):
        ids, _, api = self.pager(500)
        with patch.object(engine, 'api_call', side_effect=api):
            got, truncated = engine.list_message_ids('t', 'q', 500)
        self.assertEqual((len(got), truncated), (500, False))

    def test_detail_only_for_first_50_in_order(self):
        ids, _, api = self.pager(120)
        fetched = []

        def combined(token, path, method='GET', body=None, **kw):
            if path.startswith('users/me/messages?'):
                return api(token, path)
            mid = path.split('/')[-1].split('?')[0]
            fetched.append(mid)
            return meta(f'{mid}@x.example')
        with patch.object(engine, 'api_call', side_effect=combined):
            all_ids, details, _ = engine.scan_mailbox('t', 'q', 5000, engine.PREVIEW_DETAIL)
        self.assertEqual(len(all_ids), 120)
        self.assertEqual([d['id'] for d in details], ids[:50])
        self.assertEqual(sorted(fetched), sorted(ids[:50]))

    def test_search_mailbox_limit_still_works(self):
        ids, _, api = self.pager(30)

        def combined(token, path, method='GET', body=None, **kw):
            return api(token, path) if path.startswith('users/me/messages?') else meta('a@b.example')
        with patch.object(engine, 'api_call', side_effect=combined):
            self.assertEqual(len(engine.search_mailbox('t', 'q', limit=10)), 10)


class Purge(unittest.TestCase):
    def test_purge_chunks_of_1000(self):
        bodies = []
        with patch.object(engine, 'api_call', side_effect=lambda t, p, method='GET', body=None, **k: bodies.append(body) or {}):
            count, errors = engine.attempt_purge_messages_api('t', [f'm{i}' for i in range(2500)])
        self.assertEqual((count, errors), (2500, []))
        self.assertEqual([len(b['ids']) for b in bodies], [1000, 1000, 500])
        self.assertTrue(all(b['addLabelIds'] == ['TRASH'] for b in bodies))


class Delete(unittest.TestCase):
    def setUp(self):
        self.store = {f'm{i}': 'Spam <a@spam.example>' for i in range(5000)}
        self.calls = []

    def api(self, token, path, method='GET', body=None, **kw):
        self.calls.append((method, path, body))
        if path.endswith('batchDelete'):
            for i in body['ids']:
                self.store.pop(i, None)
            return {}
        mid = path.split('/')[-1].split('?')[0]
        if mid not in self.store:
            raise engine.GmailAPIError(404, 'gone')
        return {'id': mid, 'payload': {'headers': [{'name': 'From', 'value': self.store[mid]}]}}

    def delete(self, ids):
        with patch.object(engine, 'api_call', side_effect=self.api):
            return run(engine.cmd_delete, target='a@spam.example', message_id=ids, commit=True,
                       exact=True, force_domain=False)

    def test_accepts_5000_and_chunks_batch_delete(self):
        code, res = self.delete(list(self.store))
        self.assertEqual(code, 0, res)
        self.assertEqual(res['deleted_permanently'], 5000)
        self.assertTrue(res['delete_verified'])
        sizes = [len(c[2]['ids']) for c in self.calls if c[1].endswith('batchDelete')]
        self.assertEqual(sizes, [1000] * 5)

    def test_rejects_more_than_5000(self):
        ids = [f'x{i}' for i in range(5001)]
        code, res = self.delete(ids)
        self.assertEqual(code, 1)
        self.assertFalse(self.calls)

    def test_one_mismatch_aborts_before_any_delete(self):
        self.store['m4000'] = 'Other <z@elsewhere.example>'
        code, res = self.delete(list(self.store))
        self.assertEqual(code, 1)
        self.assertFalse(any(c[1].endswith('batchDelete') for c in self.calls))
        self.assertEqual(len(self.store), 5000)


class Filters(unittest.TestCase):
    filters = [
        {'id': 'f1', 'criteria': {'from': 'Zed@x.example'}, 'action': {'addLabelIds': ['TRASH']}},
        {'id': 'f2', 'criteria': {'from': 'alpha.example'}, 'action': {'addLabelIds': ['TRASH'], 'removeLabelIds': ['INBOX']}},
        {'id': 'f3', 'criteria': {'from': 'skip@x.example'}, 'action': {'addLabelIds': ['STARRED']}},
        {'id': 'f4', 'criteria': {'from': 'bob@x.example'}, 'action': {'removeLabelIds': ['INBOX']}},
    ]

    def test_list_json_filters_trash_and_sorts(self):
        with patch.object(engine, 'list_filters', return_value=self.filters):
            code, res = run(engine.cmd_list)
        self.assertEqual(code, 0)
        self.assertEqual([b['filter_id'] for b in res['blocked']], ['f2', 'f1'])
        self.assertEqual(res['blocked'][0], {'filter_id': 'f2', 'from': 'alpha.example', 'query': ''})

    def unblock(self, target, commit=False, id_only=True, listing=None):
        state = {'filters': list(listing or self.filters)}
        deleted = []

        def delete(token, fid):
            deleted.append(fid)
            state['filters'] = [f for f in state['filters'] if f['id'] != fid]
        with patch.object(engine, 'list_filters', side_effect=lambda t: list(state['filters'])), \
             patch.object(engine, 'delete_filter', side_effect=delete):
            code, res = run(engine.cmd_unblock, target=target, commit=commit, id_only=id_only)
        return code, res, deleted

    def test_id_only_never_substring_matches(self):
        code, res, deleted = self.unblock('x.example', commit=True)
        self.assertEqual(code, 1)
        self.assertFalse(res['success'])
        self.assertEqual(deleted, [])

    def test_commit_removes_and_verifies(self):
        code, res, deleted = self.unblock('f1', commit=True)
        self.assertEqual(code, 0)
        self.assertEqual(res, {'success': True, 'committed': True, 'removed': ['f1'], 'unblock_verified': True})
        self.assertEqual(deleted, ['f1'])

    def test_dry_run_changes_nothing(self):
        code, res, deleted = self.unblock('f2')
        self.assertEqual((code, res['committed'], res['removed']), (0, False, ['f2']))
        self.assertEqual(deleted, [])

    def test_unverified_when_filter_persists(self):
        state = list(self.filters)
        with patch.object(engine, 'list_filters', return_value=state), patch.object(engine, 'delete_filter'):
            code, res = run(engine.cmd_unblock, target='f1', commit=True, id_only=True)
        self.assertEqual(code, 1)
        self.assertFalse(res['unblock_verified'])


class Offenders(unittest.TestCase):
    def test_grouping_exclusions_and_order(self):
        senders = (['Promo <Promo@Shop.example>'] * 3 + ['promo@shop.example']
                   + ['News <news@list.example>'] * 4
                   + [USER.upper()] * 5
                   + ['x@blocked.example'] * 3 + ['y@sub.gone.example'] * 3 + ['a@done.example'] * 2
                   + ['once@single.example'] + ['Tie <b@tie.example>'] * 2 + ['a@tie.example'] * 2)
        messages = {f'm{i}': s for i, s in enumerate(senders)}
        filters = [
            {'id': '1', 'criteria': {'from': 'blocked.example'}, 'action': {'addLabelIds': ['TRASH']}},
            {'id': '2', 'criteria': {'from': 'gone.example'}, 'action': {'addLabelIds': ['TRASH']}},
            {'id': '3', 'criteria': {'from': 'a@done.example'}, 'action': {'addLabelIds': ['TRASH']}},
            {'id': '4', 'criteria': {'from': 'single.example'}, 'action': {'removeLabelIds': ['INBOX']}},
        ]
        seen = {}

        def api(token, path, method='GET', body=None, **kw):
            if path.startswith('users/me/messages?'):
                seen['q'] = path
                return {'messages': [{'id': i} for i in messages]}
            mid = path.split('/')[-1].split('?')[0]
            return meta(messages[mid], subject=f'subject {mid}', unsub=mid == 'm0')
        with patch.object(engine, 'api_call', side_effect=api), patch.object(engine, 'list_filters', return_value=filters):
            code, res = run(engine.cmd_offenders, days=7, sample=500)
        self.assertIn('newer_than%3A7d', seen['q'])
        self.assertEqual(code, 0)
        self.assertEqual(res['days'], 7)
        self.assertEqual(res['sampled'], len(senders))
        self.assertEqual([(o['sender'], o['count']) for o in res['offenders']],
                         [('news@list.example', 4), ('promo@shop.example', 4), ('a@tie.example', 2), ('b@tie.example', 2)])
        promo = res['offenders'][1]
        self.assertEqual((promo['name'], promo['has_unsubscribe']), ('Promo', True))
        self.assertEqual(set(promo), {'sender', 'name', 'count', 'has_unsubscribe', 'latest_subject'})


class Launcher(unittest.TestCase):
    def test_allowed_commands(self):
        v = launcher.validate_arguments
        self.assertEqual(v(['block', 'a@b.example', '--json']), ['block', 'a@b.example', '--json'])
        self.assertEqual(v(['list', '--json']), ['list', '--json'])
        self.assertEqual(v(['unblock', 'abc_-1', '--json', '--commit']), ['unblock', 'abc_-1', '--json', '--commit', '--id-only'])
        self.assertEqual(v(['offenders', '--json', '--days', '30', '--sample', '500'])[0], 'offenders')
        self.assertEqual(v(['delete', 'a@b.example', '--message-id', 'x', '--json'])[0], 'delete')

    def test_rejections(self):
        v = launcher.validate_arguments
        for bad in (['unblock', 'a@b.example', '--json'], ['unblock', 'x y', '--json'], ['unblock', 'abc'],
                    ['list'], ['list', '--json', '--x'], ['scan', 'a', '--json'], ['abuse-info', 'a', '--json'],
                    ['offenders', '--json', '--days', 'x'], ['offenders', '--json', '--bad', '1'], [],
                    ['unblock', 'abc', '--json', '--id-only']):
            with self.assertRaises(launcher.SetupError, msg=bad):
                v(bad)

    def test_execute_appends_id_only(self):
        with patch.object(engine, 'cmd_unblock', return_value=0) as cmd:
            launcher.execute(['unblock', 'abc', '--json'], {}, USER)
        self.assertTrue(cmd.call_args.args[0].id_only)


if __name__ == '__main__':
    unittest.main()
