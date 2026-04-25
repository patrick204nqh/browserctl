# browserctl login demo — VHS tape
# Produces: docs/assets/terminal.gif
#
# Requirements: vhs (brew install vhs)
# The daemon must NOT be running before this tape starts.

Output docs/assets/terminal.gif
Output docs/assets/terminal.webp

# ---------- terminal appearance ----------
Set Theme      "Catppuccin Mocha"
Set FontSize   14
Set FontFamily "JetBrains Mono"
Set Width      900
Set Height     520
Set Shell      "bash"
Set TypingSpeed 60ms
Set PlaybackSpeed 1

# ---------- preamble ----------
Type "# browserctl — persistent browser sessions for AI agents"
Sleep 800ms
Enter
Sleep 300ms

# ---------- start the daemon ----------
Type "browserd &"
Sleep 400ms
Enter
Sleep 4s

# poll until the daemon answers — max ~8 s
Type "until browserctl ping 2>/dev/null; do sleep 0.5; done && echo 'daemon ready'"
Sleep 400ms
Enter
Sleep 5s

# ---------- open the login page ----------
Type "browserctl open main --url https://the-internet.herokuapp.com/login"
Sleep 400ms
Enter
Sleep 4s

# ---------- snapshot: AI sees the page as structured elements ----------
Type "browserctl snap main"
Sleep 400ms
Enter
Sleep 4s

# ---------- fill & submit without CSS selectors ----------
Type "# fill credentials using ref IDs — no selectors needed"
Sleep 500ms
Enter
Type "browserctl fill main --ref e1 --value tomsmith"
Sleep 400ms
Enter
Sleep 2s

Type "browserctl fill main --ref e2 --value SuperSecretPassword!"
Sleep 400ms
Enter
Sleep 2s

Type "browserctl click main --ref e3"
Sleep 400ms
Enter
Sleep 4s

# ---------- prove session persisted: URL shows /secure ----------
Type "# session persisted — browser is on the secure page"
Sleep 500ms
Enter
Type "browserctl url main"
Sleep 400ms
Enter
Sleep 2s

# ---------- screenshot the logged-in state ----------
Type "browserctl shot main --out docs/assets/demo_login.png"
Sleep 400ms
Enter
Sleep 3s

# ---------- tear down ----------
Type "browserctl shutdown"
Sleep 400ms
Enter
Sleep 2s

Type "# done — session, screenshot, and this recording are all automated"
Sleep 1500ms
Enter
Sleep 1s
