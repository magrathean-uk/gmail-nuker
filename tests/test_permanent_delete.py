"""Permanent deletion boundary checks: synthetic Gmail only, no live requests."""
import argparse
import contextlib
import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
import urllib.error
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('gmail_delete_engine', str(Path(__file__).resolve().parents[1] / 'bin/gmail-block'))
spec = importlib.util.spec_from_loader(loader.name, loader)
engine = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = engine
loader.exec_module(engine)


def forbidden(*args, **kwargs):
    raise AssertionError('A test attempted external network access')


class DeleteChecks(unittest.TestCase):
    def setUp(self):
        self.messages = {'selected-one': 'Sender <sender@news.spam.example>',
                         'selected-two': 'other@spam.example', 'unselected': 'new@spam.example'}
        self.calls = []
        self.refuse_deletion = False
        self.read_error = None
        self.network = patch.object(engine.urllib.request, 'urlopen', side_effect=forbidden)
        self.network.start()
        self.addCleanup(self.network.stop)

    def api(self, token, path, method='GET', body=None, **kwargs):
        self.calls.append((method, path, body))
        if path == 'users/me/messages/batchDelete':
            self.assertEqual(method, 'POST')
            if not self.refuse_deletion:
                for mid in body['ids']:
                    self.messages.pop(mid, None)
            return {}
        mid = path.split('/')[-1].split('?')[0]
        if self.read_error:
            raise engine.GmailAPIError(self.read_error, 'Synthetic verification error')
        if mid not in self.messages:
            raise engine.GmailAPIError(404, 'Synthetic not found')
        return {'id': mid, 'payload': {'headers': [{'name': 'From', 'value': self.messages[mid]}]}}

    def run_delete(self, commit=True, ids=None, target='sender@spam.example', exact=False):
        args = argparse.Namespace(target=target, message_id=ids or ['selected-one', 'selected-two'],
                                  commit=commit, exact=exact, force_domain=False, json=True,
                                  sa='/synthetic/credential.json', user='fixture@example.test')
        out = io.StringIO()
        with patch.object(engine, 'get_sa_token', return_value=('synthetic', True)) as auth, \
             patch.object(engine, 'api_call', side_effect=self.api), \
             patch.object(engine, 'trigger_one_click_unsubscribe', side_effect=forbidden), \
             patch.object(engine, 'attempt_purge_imap', side_effect=forbidden), \
             contextlib.redirect_stdout(out):
            code = engine.cmd_delete(args)
        self.assertEqual(auth.call_args.kwargs['permanent_delete'], commit)
        return code, json.loads(out.getvalue())

    def test_preview_never_mutates(self):
        code, result = self.run_delete(commit=False)
        self.assertEqual(code, 0)
        self.assertEqual(result['selected_count'], 2)
        self.assertTrue(all(method == 'GET' for method, _, _ in self.calls))
        self.assertEqual(len(self.messages), 3)

    def test_invalid_id_is_rejected_before_authentication(self):
        args = argparse.Namespace(target='spam.example', message_id=['../other'], commit=True, json=True)
        with patch.object(engine, 'get_sa_token', side_effect=forbidden), \
             patch.object(engine, 'api_call', side_effect=forbidden), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(engine.cmd_delete(args), 1)

    def test_only_preview_ids_are_deleted_and_verified(self):
        code, result = self.run_delete(ids=['selected-one', 'selected-one', 'selected-two'])
        self.assertEqual(code, 0)
        self.assertEqual(result['deleted_permanently'], 2)
        self.assertTrue(result['delete_verified'])
        self.assertEqual(result['remaining'], 0)
        self.assertIn('unselected', self.messages)
        writes = [(path, body) for method, path, body in self.calls if method != 'GET']
        self.assertEqual(writes, [('users/me/messages/batchDelete', {'ids': ['selected-one', 'selected-two']})])

    def test_wrong_sender_aborts_entire_batch(self):
        self.messages['selected-two'] = 'other@elsewhere.example'
        code, result = self.run_delete()
        self.assertEqual(code, 1)
        self.assertFalse(result['success'])
        self.assertTrue(all(method == 'GET' for method, _, _ in self.calls))
        self.assertIn('selected-one', self.messages)

    def test_exact_sender_is_not_expanded(self):
        code, result = self.run_delete(target='sender@spam.example', exact=True)
        self.assertEqual(code, 1)
        self.assertFalse(result['success'])
        self.assertTrue(all(method == 'GET' for method, _, _ in self.calls))

    def test_already_missing_is_idempotent(self):
        self.messages.pop('selected-one')
        code, result = self.run_delete(ids=['selected-one'])
        self.assertEqual(code, 0)
        self.assertEqual(result['already_missing'], 1)
        self.assertEqual(result['deleted_permanently'], 0)
        self.assertTrue(result['delete_verified'])
        self.assertTrue(all(method == 'GET' for method, _, _ in self.calls))

    def test_empty_batch_response_does_not_prove_success(self):
        self.refuse_deletion = True
        code, result = self.run_delete()
        self.assertEqual(code, 1)
        self.assertFalse(result['delete_verified'])
        self.assertEqual(result['remaining'], 2)

    def test_permission_error_is_not_missing_message(self):
        self.read_error = 403
        code, result = self.run_delete()
        self.assertEqual(code, 1)
        self.assertFalse(result['success'])
        self.assertTrue(all(method == 'GET' for method, _, _ in self.calls))

    def test_full_mail_scope_is_required_without_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            credential = Path(tmp) / 'synthetic.json'
            credential.write_text('{}')
            credential.chmod(0o600)
            error = urllib.error.HTTPError(engine.TOKEN_URL, 400, 'Synthetic', {}, io.BytesIO(b'{"error":"unauthorized_client"}'))
            with patch.object(engine, '_sign_assertion', return_value='synthetic-assertion') as sign, \
                 patch.object(engine.urllib.request, 'urlopen', side_effect=error) as network:
                with self.assertRaises(RuntimeError):
                    engine.get_sa_token(credential, 'fixture@example.test', permanent_delete=True)
                self.assertIn('https://mail.google.com/', sign.call_args.args[2])
                self.assertEqual(network.call_count, 1)
            error.close()

    def test_preview_includes_existing_trash_when_requested(self):
        calls = []
        with patch.object(engine, 'api_call', side_effect=lambda token, path: calls.append(path) or {}):
            engine.search_mailbox('synthetic', 'from:spam.example', include_spam_trash=True)
        self.assertIn('includeSpamTrash=true', calls[0])

    def test_trash_preview_does_not_repeat_unsubscribe(self):
        args = argparse.Namespace(target='sender@spam.example', exact=False, force_domain=False,
                                  json=True, sa='/synthetic/key.json', user='fixture@example.test',
                                  limit=50, include_spam_trash=True, commit=True, purge=False, report_abuse=False)
        def api(token, path, **kwargs):
            if path == 'users/me/settings/filters':
                return {'filter': [{'id': 'fixture-filter', 'criteria': {'from': 'spam.example'},
                                    'action': {'addLabelIds': ['TRASH']}}]}
            if path.startswith('users/me/messages?'):
                return {'messages': [{'id': 'selected-one'}]}
            return {'labelIds': ['TRASH'], 'payload': {'headers': [
                {'name': 'From', 'value': 'sender@spam.example'},
                {'name': 'List-Unsubscribe', 'value': '<https://unsubscribe.invalid/fixture>'}]}}
        with patch.object(engine, 'get_sa_token', return_value=('synthetic', True)), \
             patch.object(engine, 'api_call', side_effect=api), \
             patch.object(engine, 'resolve_mx_records', return_value=[]), \
             patch.object(engine, 'lookup_rdap_abuse', return_value={'registrar': 'Fixture', 'abuse_emails': []}), \
             patch.object(engine, 'trigger_one_click_unsubscribe', side_effect=forbidden), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(engine.cmd_block(args), 0)


if __name__ == '__main__':
    unittest.main()
