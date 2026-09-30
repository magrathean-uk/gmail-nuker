"""Synthetic credential/process boundary checks; never invokes 1Password or Google."""
import contextlib
import importlib.machinery
import importlib.util
import io
import json
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
spec = importlib.util.spec_from_file_location('app_launcher', ROOT / 'app/engine_launcher.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

class LauncherChecks(unittest.TestCase):
    reference = 'op://Fixture/VaultItem/credential'
    credential = {'type':'service_account','client_email':'fixture@example.test','private_key':'NOT A REAL KEY'}

    def test_credential_is_read_without_shell_and_returned_in_memory(self):
        response = subprocess.CompletedProcess([],0,json.dumps(self.credential),'')
        with patch.object(launcher.subprocess,'run',return_value=response) as run:
            self.assertEqual(launcher.read_credential(self.reference,'fixture@example.test',Path('/mock/op')),self.credential)
        self.assertEqual(run.call_args.args[0],['/mock/op','read',self.reference])
        self.assertTrue(run.call_args.kwargs['capture_output'])
        self.assertNotIn('shell',run.call_args.kwargs)

    def test_secret_stderr_is_not_exposed(self):
        response = subprocess.CompletedProcess([],1,'','SYNTHETIC SECRET DO NOT EXPOSE')
        with patch.object(launcher.subprocess,'run',return_value=response):
            with self.assertRaises(launcher.SetupError) as error:
                launcher.read_credential(self.reference,'',Path('/mock/op'))
        self.assertNotIn('SYNTHETIC SECRET',str(error.exception))

    def test_timeout_becomes_actionable_error(self):
        with patch.object(launcher.subprocess,'run',side_effect=subprocess.TimeoutExpired('op',120)):
            with self.assertRaisesRegex(launcher.SetupError,'timed out'):
                launcher.read_credential(self.reference,'',Path('/mock/op'))

    def test_wrong_service_account_is_rejected(self):
        response = subprocess.CompletedProcess([],0,json.dumps(self.credential),'')
        with patch.object(launcher.subprocess,'run',return_value=response):
            with self.assertRaises(launcher.SetupError):
                launcher.read_credential(self.reference,'other@example.test',Path('/mock/op'))

    def test_reference_required_before_process_starts(self):
        with patch.object(launcher.subprocess,'run') as run:
            with self.assertRaises(launcher.SetupError):
                launcher.read_credential('not-a-reference','',Path('/mock/op'))
        run.assert_not_called()

    def test_check_reads_profile_and_does_not_mutate_mail(self):
        with patch.object(engine,'get_sa_token',return_value=('synthetic-token',True)) as token, \
             patch.object(engine,'api_call',return_value={'emailAddress':'fixture@example.test'}) as api, \
             patch.object(engine,'cmd_block') as block,patch.object(engine,'cmd_delete') as delete, \
             contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(launcher.execute(['check'],self.credential,'fixture@example.test'),0)
        token.assert_called_once_with(self.credential,'fixture@example.test')
        api.assert_called_once_with('synthetic-token','users/me/profile')
        block.assert_not_called();delete.assert_not_called()
        self.assertTrue(json.loads(out.getvalue())['success'])

    def test_block_uses_memory_credential_and_configured_mailbox(self):
        with patch.object(engine,'cmd_block',return_value=0) as block:
            launcher.execute(['block','spam.example','--json','--commit'],self.credential,'fixture@example.test')
        args=block.call_args.args[0]
        self.assertIs(args.sa,self.credential)
        self.assertEqual(args.user,'fixture@example.test')
        self.assertTrue(args.commit)

    def test_delete_preserves_selected_ids_and_commit(self):
        with patch.object(engine,'cmd_delete',return_value=0) as delete:
            launcher.execute(['delete','spam.example','--json','--commit','--message-id','synthetic-id'],self.credential,'fixture@example.test')
        args=delete.call_args.args[0]
        self.assertIs(args.sa,self.credential)
        self.assertEqual(args.message_id,['synthetic-id'])
        self.assertTrue(args.commit)

    def test_unsupported_commands_do_not_reach_engine(self):
        with self.assertRaises(launcher.SetupError):
            launcher.execute(['unblock','spam.example','--commit'],self.credential,'fixture@example.test')

    def test_engine_auth_accepts_memory_credentials_without_file_access(self):
        response=io.BytesIO(b'{"access_token":"synthetic-token"}')
        with patch.object(engine,'_sign_assertion',return_value='synthetic-jwt') as sign, \
             patch.object(engine.urllib.request,'urlopen',return_value=response), \
             patch.object(engine.Path,'read_text',side_effect=AssertionError('Must not read a key file')):
            token,modify=engine.get_sa_token(self.credential,'fixture@example.test',permanent_delete=True)
        self.assertEqual(token,'synthetic-token');self.assertTrue(modify)
        self.assertIs(sign.call_args.args[0],self.credential)
        self.assertIn('https://mail.google.com/',sign.call_args.args[2])

    def test_missing_signing_runtime_rejects_before_reading_credential(self):
        with patch.object(engine,'HAVE_CRYPTOGRAPHY',False),patch.object(launcher,'read_credential') as read:
            with self.assertRaisesRegex(launcher.SetupError,'in-memory signing'):
                launcher.main()
        read.assert_not_called()

if __name__ == '__main__': unittest.main()
