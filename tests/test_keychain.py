"""Keychain credential-source checks; subprocess is mocked, no real Keychain is read."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
loader = importlib.machinery.SourceFileLoader('gmail_engine', str(ROOT / 'bin/gmail-block'))
spec = importlib.util.spec_from_loader(loader.name, loader)
engine = importlib.util.module_from_spec(spec)
sys.modules[loader.name] = engine
loader.exec_module(engine)
spec = importlib.util.spec_from_file_location('app_launcher_kc', ROOT / 'app/engine_launcher.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

CREDENTIAL = {'type': 'service_account', 'client_email': 'fixture@example.test', 'private_key': 'NOT A REAL KEY'}
COMPACT = json.dumps(CREDENTIAL, separators=(',', ':'))


def completed(code, out='', err=''):
    return subprocess.CompletedProcess([], code, out, err)


LOGIN = '/fixture/Library/Keychains/login.keychain-db'


def fake_security(secret=COMPACT + '\n', code=0, login_ok=True):
    def run(command, **kwargs):
        if command[1] == 'login-keychain':
            return completed(0 if login_ok else 1, '    "%s"\n' % LOGIN if login_ok else '')
        return completed(code, secret, secret)
    return run


class ReaderChecks(unittest.TestCase):
    def test_uses_apple_security_tool_with_login_keychain_argument_list(self):
        with patch.object(engine.subprocess, 'run', side_effect=fake_security()) as run:
            self.assertEqual(engine.read_keychain_credential(), CREDENTIAL)
        read = run.call_args_list[-1]
        self.assertEqual(read.args[0], ['/usr/bin/security', 'find-generic-password', '-s',
                                        'uk.magrathean.gmail-nuker', '-a', 'service-account', '-w', LOGIN])
        self.assertTrue(read.kwargs['capture_output'])
        self.assertIn('timeout', read.kwargs)
        self.assertNotIn('shell', read.kwargs)

    def test_falls_back_to_no_keychain_argument(self):
        with patch.object(engine.subprocess, 'run', side_effect=fake_security(login_ok=False)) as run:
            engine.read_keychain_credential()
        self.assertEqual(run.call_args_list[-1].args[0][-1], '-w')

    def test_hex_output_is_decoded(self):
        with patch.object(engine.subprocess, 'run', side_effect=fake_security(COMPACT.encode().hex() + '\n')):
            self.assertEqual(engine.read_keychain_credential(), CREDENTIAL)

    def test_failure_hides_tool_output(self):
        with patch.object(engine.subprocess, 'run', side_effect=fake_security('SYNTHETIC SECRET', 44)):
            with self.assertRaises(RuntimeError) as error:
                engine.read_keychain_credential()
        self.assertNotIn('SYNTHETIC SECRET', str(error.exception))

    def test_invalid_json_hides_content(self):
        with patch.object(engine.subprocess, 'run', side_effect=fake_security('SYNTHETIC SECRET')):
            with self.assertRaises(RuntimeError) as error:
                engine.read_keychain_credential()
        self.assertNotIn('SYNTHETIC SECRET', str(error.exception))

    def test_timeout_is_actionable(self):
        with patch.object(engine.subprocess, 'run', side_effect=subprocess.TimeoutExpired('security', 30)):
            with self.assertRaisesRegex(RuntimeError, 'did not respond'):
                engine.read_keychain_credential()


class LauncherChecks(unittest.TestCase):
    def test_keychain_source_validates_and_returns_credential(self):
        with patch.object(engine, 'read_keychain_credential', return_value=dict(CREDENTIAL)):
            self.assertEqual(launcher.read_keychain('fixture@example.test'), CREDENTIAL)

    def test_keychain_source_rejects_wrong_email(self):
        with patch.object(engine, 'read_keychain_credential', return_value=dict(CREDENTIAL)):
            with self.assertRaises(launcher.SetupError):
                launcher.read_keychain('other@example.test')

    def test_missing_key_becomes_setup_error(self):
        with patch.object(engine, 'read_keychain_credential', side_effect=RuntimeError('No Google key is stored on this Mac. Import it in Settings.')):
            with self.assertRaisesRegex(launcher.SetupError, 'Import it'):
                launcher.read_keychain('')

    def _run_main(self, environment):
        base = {'GMAIL_NUKER_MAILBOX': 'fixture@example.test',
                'GMAIL_NUKER_SECRET_REFERENCE': 'op://Fixture/VaultItem/credential',
                'GMAIL_NUKER_SERVICE_ACCOUNT': ''}
        with patch.dict(os.environ, {**base, **environment}, clear=False), \
             patch.object(engine, 'HAVE_CRYPTOGRAPHY', True), \
             patch.object(launcher, 'execute', return_value=0), \
             patch.object(launcher, 'read_keychain', return_value=dict(CREDENTIAL)) as keychain, \
             patch.object(launcher, 'read_credential', return_value=dict(CREDENTIAL)) as onepassword:
            launcher.main()
        return keychain, onepassword

    def test_keychain_source_selected_by_environment(self):
        keychain, onepassword = self._run_main({'GMAIL_NUKER_CREDENTIAL_SOURCE': 'keychain'})
        keychain.assert_called_once(); onepassword.assert_not_called()

    def test_missing_or_unknown_source_keeps_1password(self):
        for value in (None, '', 'other'):
            environment = {} if value is None else {'GMAIL_NUKER_CREDENTIAL_SOURCE': value}
            with patch.dict(os.environ, {}, clear=False):
                os.environ.pop('GMAIL_NUKER_CREDENTIAL_SOURCE', None)
                keychain, onepassword = self._run_main(environment)
            keychain.assert_not_called(); onepassword.assert_called_once()


class CliChecks(unittest.TestCase):
    def test_sa_keychain_resolves_through_reader_not_a_file(self):
        args = engine.build_parser().parse_args(['--sa', 'keychain', 'list'])
        with patch.object(engine, 'read_keychain_credential', return_value=dict(CREDENTIAL)) as reader, \
             patch.object(engine, '_sign_assertion', return_value='jwt') as sign, \
             patch.object(engine.urllib.request, 'urlopen', return_value=__import__('io').BytesIO(b'{"access_token":"t"}')), \
             patch.object(engine.Path, 'is_file', side_effect=AssertionError('Must not touch a file')):
            token, _ = engine.get_sa_token(args.sa, 'fixture@example.test')
        reader.assert_called_once()
        self.assertEqual(token, 't')
        self.assertEqual(sign.call_args.args[0], CREDENTIAL)

    def test_relative_keychain_path_is_a_file_not_the_keychain(self):
        args = engine.build_parser().parse_args(['--sa', './keychain', 'list'])
        self.assertEqual(args.sa, './keychain')
        with patch.object(engine, 'read_keychain_credential') as reader:
            with self.assertRaises(FileNotFoundError):
                engine.get_sa_token(args.sa, 'fixture@example.test')
        reader.assert_not_called()

    def test_environment_default_keychain_is_recognised(self):
        with patch.object(engine, 'read_keychain_credential', side_effect=RuntimeError('x')) as reader:
            with self.assertRaises(RuntimeError):
                engine.get_sa_token('keychain', 'fixture@example.test')
        reader.assert_called_once()

    def test_help_mentions_keychain(self):
        self.assertIn('keychain', engine.build_parser().format_help())


if __name__ == '__main__':
    unittest.main()
