# Privacy Policy

LayoutFixer is a keyboard utility. It sees everything you type, so the rules below are the point
of the project, not a formality.

## What the app never does

- **It does not save what you type.** Keystrokes are never written to disk, a database or a log file.
- **It has no diary or history feature**, and one will not be added.
- **It does not connect to the internet.** The source code contains no networking calls of any kind:
  no updates check, no analytics, no crash reporting. You can verify this by searching the sources
  for `URLSession`, `Network`, `socket` or `http`.
- **It does not read passwords.** In password fields macOS turns on secure input and the app receives
  nothing. In addition, the app checks the focused field type and skips known password managers
  (Passwords, Keychain Access, 1Password, Bitwarden, LastPass, KeePassXC, Dashlane).
- **It ignores logins and codes.** A word containing digits, `@`, a dot or an underscore is never
  replaced.

## What is kept in memory

Only the word you are typing right now and the previous word, as key codes, so that a replacement
can be undone. This memory is cleared after every space, punctuation mark, mouse click, app switch
and window change. Nothing else is retained.

## What is written to disk

Only what you can see and edit inside the app:

| File | Contents |
|---|---|
| `~/Library/Application Support/LayoutFixer/exceptions.txt` | Words you excluded from replacement. Plain text, letters only, 2–40 characters. |
| `~/Library/Preferences/local.layoutfixer.plist` | Settings, shortcuts, chosen dictionaries and the snippets you typed in yourself. |

Delete both files and the app forgets everything it knew.

## Clipboard

The selection actions (convert layout, invert case, transliterate) copy the selected text, change
it and paste it back, then restore the previous clipboard contents. The text exists in memory for a
fraction of a second and is never stored.

## Dictionaries

Spell checking uses `NSSpellChecker` — the dictionaries built into macOS. Words are checked on your
Mac; nothing is sent anywhere.

## Permissions

The app asks for Accessibility permission. It is required to receive key events and to insert the
corrected text. It is used for nothing else.
