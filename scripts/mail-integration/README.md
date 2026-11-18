# Mail.app integration

Blocks the sender of the message(s) selected in Mail.app using the installed Gmail Nuker app.

**The shortcut is built into the app.** While Gmail Nuker is running (it lives in the menu bar and can open at login), select a message in Mail and press Control-Option-Command-B, or choose "Block Sender of Selected Mail Message" from the menu bar icon. Nothing needs installing; macOS asks once to let Gmail Nuker control Mail. The AppleScript below is an alternative for people who prefer Mail's Script menu or Shortcuts.

For each distinct sender it creates a Gmail filter that sends future mail from that exact address to Trash, and moves existing mail from that exact sender to Trash. Trash is recoverable. Nothing is permanently deleted, and it refuses to block your own address. A notification reports the result.

It needs the packaged app at `/Applications/Gmail Nuker.app`, configured in Settings (mailbox plus a key in the macOS Keychain or 1Password). The package copies `block-sender.sh` to `Contents/Resources/block-sender.sh`; the script reads the app's saved settings, so there is nothing else to configure. With a 1Password key, 1Password asks for approval; with a Keychain key it does not.

## Install the AppleScript (optional alternative)

1. Open `block-sender.applescript` in Script Editor and save it, or copy the file, into `~/Library/Application Scripts/com.apple.mail/`.
2. Run it from the Script menu (Script Editor, Preferences, show Script menu) or from Shortcuts with a "Run AppleScript" action.
3. Select one or more messages in Mail and run it. Allow the Automation prompt for Mail the first time.

To test the script without Mail: `"/Applications/Gmail Nuker.app/Contents/Resources/block-sender.sh" "Name <sender@example.com>"`.
