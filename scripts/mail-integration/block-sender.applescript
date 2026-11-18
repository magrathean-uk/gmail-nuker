-- Blocks the sender of the selected Mail message(s) via Gmail Nuker.
on run
	tell application "Mail"
		set msgs to selection
		if (count of msgs) is 0 then
			display notification "Select a message first." with title "Block sender"
			return
		end if
		set senders to {}
		repeat with m in msgs
			set s to sender of m
			if senders does not contain s then set end of senders to s
		end repeat
	end tell
	repeat with s in senders
		do shell script "/bin/bash " & quoted form of "/Applications/Gmail Nuker.app/Contents/Resources/block-sender.sh" & " " & quoted form of (s as text) & " >/dev/null 2>&1 &"
	end repeat
end run
