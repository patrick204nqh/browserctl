# browserctl login demo — VHS tape
# Produces: docs/assets/terminal.gif
#
# Target: https://moatazeldebsy.github.io/test-automation-practices
# Requirements: vhs gum (brew install vhs gum)
# The daemon must NOT be running before this tape starts.

Output docs/assets/terminal.gif

# ---------- terminal appearance ----------
Set Theme         "Atom"
Set FontSize      12
Set Width         1100
Set Height        550
Set Shell         "bash"
Set TypingSpeed   60ms
Set PlaybackSpeed 1

# ---------- preamble ----------
# Chain into one command so `clear` wipes the echoed text before gum renders.
Hide
Type "export PS1='❯ ' && clear && printf '\n\n\n'; gum style --foreground '#61afef' --bold '  browserctl'; gum style --foreground '#abb2bf' '  persistent browser sessions for AI agents and CI'"
Enter
Show
Sleep 600ms

# ---------- start the daemon ----------
Type "bundle exec browserd &>/tmp/browserd.log &"
Sleep 400ms
Enter
Sleep 5s

# ---------- open the login page ----------
Type "bundle exec browserctl open main --url https://moatazeldebsy.github.io/test-automation-practices/#/auth"
Sleep 400ms
Enter
Sleep 4s

# ---------- snapshot ----------
Type "bundle exec browserctl snap main"
Sleep 400ms
Enter
Sleep 4s

# ---------- fill & submit ----------
Type "bundle exec browserctl fill main --ref e1 --value admin"
Sleep 400ms
Enter
Sleep 2s

Type "bundle exec browserctl fill main --ref e2 --value admin"
Sleep 400ms
Enter
Sleep 2s

Type "bundle exec browserctl click main --ref e3"
Sleep 400ms
Enter
Sleep 4s

# ---------- snapshot after login ----------
Type "bundle exec browserctl snap main"
Sleep 400ms
Enter
Sleep 4s

# ---------- screenshot ----------
Type "bundle exec browserctl shot main --out docs/assets/demo_auth.png"
Sleep 400ms
Enter
Sleep 3s

# ---------- tear down ----------
Type "bundle exec browserctl shutdown"
Sleep 400ms
Enter
Sleep 3s
