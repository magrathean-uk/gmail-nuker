"""Private-process bridge between the native app, 1Password and the mail engine.

Built as a standalone executable. The service-account JSON stays in memory.
Raw 1Password output is not forwarded to the GUI.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

import certifi
import gmail_engine


class SetupError(RuntimeError):
    pass


def read_credential(reference, expected_email, op_path):
    if not reference.startswith('op://') or len(reference.split('/')) not in (5, 6):
        raise SetupError('Enter a valid 1Password secret reference in Settings.')
    try:
        response = subprocess.run([str(op_path), 'read', reference], capture_output=True,
                                  text=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise SetupError('1Password approval timed out. Unlock 1Password and try again.') from None
    except OSError:
        raise SetupError('The 1Password helper could not start. Reinstall the app.') from None
    if response.returncode:
        raise SetupError('Unlock 1Password and approve access. Enable “Integrate with 1Password CLI” in 1Password Settings → Developer.')
    try:
        credential = json.loads(response.stdout)
        if (credential.get('type') != 'service_account'
                or not credential.get('private_key')
                or not credential.get('client_email')
                or (expected_email and credential['client_email'] != expected_email)):
            raise ValueError()
    except (ValueError, AttributeError, TypeError):
        raise SetupError('The selected 1Password field is not the expected Google service-account JSON.') from None
    return credential


def execute(arguments, credential, mailbox):
    if arguments == ['check']:
        token, _ = gmail_engine.get_sa_token(credential, mailbox)
        profile = gmail_engine.api_call(token, 'users/me/profile')
        if profile.get('emailAddress', '').lower() != mailbox.lower():
            raise SetupError('Google returned a different mailbox. Check the account in Settings.')
        print(json.dumps({'success': True, 'committed': False}))
        return 0
    if not arguments or arguments[0] not in ('block', 'delete') or '--json' not in arguments:
        raise SetupError('The app requested an unsupported mail operation.')
    args = gmail_engine.build_parser().parse_args(arguments)
    args.sa = credential
    args.user = mailbox
    # The standalone bridge deliberately offers no IMAP/app-password fallback.
    gmail_engine.SMTP_CREDS_PATH = Path('/dev/null')
    if args.command == 'block':
        return gmail_engine.cmd_block(args)
    return gmail_engine.cmd_delete(args)


def main():
    if not gmail_engine.HAVE_CRYPTOGRAPHY:
        raise SetupError('The in-memory signing runtime is unavailable. Reinstall the app before connecting to 1Password.')
    mailbox = os.environ.get('GMAIL_NUKER_MAILBOX', '').strip()
    reference = os.environ.get('GMAIL_NUKER_SECRET_REFERENCE', '').strip()
    expected_email = os.environ.get('GMAIL_NUKER_SERVICE_ACCOUNT', '').strip()
    if '@' not in mailbox or any(c.isspace() for c in mailbox):
        raise SetupError('Enter your Workspace email address in Settings.')
    op_path = Path(sys.executable).resolve().parents[2] / 'Helpers' / 'op'
    os.environ['SSL_CERT_FILE'] = certifi.where()
    credential = read_credential(reference, expected_email, op_path)
    try:
        return execute(sys.argv[1:], credential, mailbox)
    finally:
        credential.clear()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SetupError as error:
        print(json.dumps({'success': False, 'error': str(error)}))
        sys.exit(1)
    except Exception:
        print(json.dumps({'success': False, 'error': 'Could not connect to Google. Check your connection and Workspace delegation, then try again.'}))
        sys.exit(1)
