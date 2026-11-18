"""Private-process bridge between the native app, the credential store and the mail engine.

Built as a standalone executable. The service-account JSON (macOS Keychain or 1Password) stays in memory.
Raw credential-tool output is not forwarded to the GUI.
"""
import json
import os
import re
from pathlib import Path
import subprocess
import sys

import certifi
import gmail_engine


class SetupError(RuntimeError):
    pass


def validate_credential(source, expected_email, failure='The stored Google key is not the expected service-account JSON.'):
    """Parse and check a service-account JSON string (or dict); never echo its content."""
    try:
        credential = json.loads(source) if isinstance(source, (str, bytes)) else source
        if (credential.get('type') != 'service_account'
                or not credential.get('private_key')
                or not credential.get('client_email')
                or (expected_email and credential['client_email'] != expected_email)):
            raise ValueError()
    except (ValueError, AttributeError, TypeError):
        raise SetupError(failure) from None
    return credential


def read_keychain(expected_email):
    try:
        credential = gmail_engine.read_keychain_credential()
    except RuntimeError as error:
        raise SetupError(str(error)) from None
    return validate_credential(credential, expected_email,
                               'The Google key stored on this Mac is not the expected service-account JSON. Import it again in Settings.')


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
    return validate_credential(response.stdout, expected_email,
                               'The selected 1Password field is not the expected Google service-account JSON.')


def validate_arguments(arguments):
    """Allow exactly the app's commands; return the argument list to parse (unblock gains --id-only)."""
    unsupported = SetupError('The app requested an unsupported mail operation.')
    if not arguments or '--json' not in arguments:
        raise unsupported
    command = arguments[0]
    if command in ('block', 'delete'):
        return list(arguments)
    if command == 'list':
        if arguments != ['list', '--json']:
            raise unsupported
        return list(arguments)
    if command == 'unblock':
        if len(arguments) < 3 or not re.fullmatch(r'[A-Za-z0-9_-]+', arguments[1]):
            raise unsupported
        if any(a not in ('--json', '--commit') for a in arguments[2:]):
            raise unsupported
        return list(arguments) + ['--id-only']
    if command == 'offenders':
        rest = arguments[1:]
        index = 0
        while index < len(rest):
            if rest[index] == '--json':
                index += 1
            elif rest[index] in ('--days', '--sample') and index + 1 < len(rest) and re.fullmatch(r'[0-9]{1,5}', rest[index + 1]):
                index += 2
            else:
                raise unsupported
        return list(arguments)
    raise unsupported


def execute(arguments, credential, mailbox):
    if arguments == ['check']:
        token, _ = gmail_engine.get_sa_token(credential, mailbox)
        profile = gmail_engine.api_call(token, 'users/me/profile')
        if profile.get('emailAddress', '').lower() != mailbox.lower():
            raise SetupError('Google returned a different mailbox. Check the account in Settings.')
        print(json.dumps({'success': True, 'committed': False}))
        return 0
    arguments = validate_arguments(arguments)
    args = gmail_engine.build_parser().parse_args(arguments)
    args.sa = credential
    args.user = mailbox
    # The standalone bridge deliberately offers no IMAP/app-password fallback.
    gmail_engine.SMTP_CREDS_PATH = Path('/dev/null')
    if args.command == 'block':
        return gmail_engine.cmd_block(args)
    handlers = {'delete': gmail_engine.cmd_delete, 'list': gmail_engine.cmd_list,
                'unblock': gmail_engine.cmd_unblock, 'offenders': gmail_engine.cmd_offenders}
    return handlers[args.command](args)


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
    if os.environ.get('GMAIL_NUKER_CREDENTIAL_SOURCE', '').strip() == 'keychain':
        credential = read_keychain(expected_email)
    else:
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
