# browserctl login demo — VHS tape
# Produces: docs/assets/terminal.gif
#
# Target: https://moatazeldebsy.github.io/test-automation-practices
# Requirements: vhs (brew install vhs)
# The daemon must NOT be running before this tape starts.

Output docs/assets/terminal.gif
Output docs/assets/terminal.webp

# ---------- terminal appearance ----------
Set Theme      "Catppuccin Mocha"
Set FontSize   12
Set FontFamily "Fira Code"
Set Width      1100
Set Height     550
Set Shell      "bash"
Set TypingSpeed 60ms
Set PlaybackSpeed 1

# ---------- preamble ----------
Type "# browserctl — persistent browser sessions for AI agents and CI workflows"
Sleep 800ms
Enter
Sleep 300ms

# ---------- start the daemon ----------
Type "bundle exec browserd &"
Sleep 400ms
Enter
Sleep 4s

# poll until the daemon answers — max ~8 s
Type "until bundle exec browserctl ping 2>/dev/null; do sleep 0.5; done && echo 'daemon ready'"
Sleep 400ms
Enter
Sleep 5s

# ---------- open the login page ----------
Type "bundle exec browserctl open main --url https://moatazeldebsy.github.io/test-automation-practices/#/auth"
Sleep 400ms
Enter
Sleep 4s

# ---------- snapshot: AI sees the page as structured elements ----------
Type "bundle exec browserctl snap main"
Sleep 400ms
Enter
Sleep 4s

# ---------- fill & submit without CSS selectors ----------
Type "# fill credentials using ref IDs — no selectors needed"
Sleep 500ms
Enter
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

# ---------- prove login succeeded: snapshot shows the authenticated UI ----------
Type "# login succeeded — snapshot reflects the authenticated state"
Sleep 500ms
Enter
Type "bundle exec browserctl snap main"
Sleep 400ms
Enter
Sleep 4s

# ---------- screenshot the logged-in state ----------
Type "bundle exec browserctl shot main --out docs/assets/demo_auth.png"
Sleep 400ms
Enter
Sleep 3s

# ---------- tear down ----------
Type "bundle exec browserctl shutdown"
Sleep 400ms
Enter
Sleep 2s

Type "# done — session, screenshot, and this recording are all automated"
Sleep 1500ms
Enter
Sleep 1s
