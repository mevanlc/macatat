# macatat

A menu-bar app that types the clipboard's text into the frontmost app by sending synthetic
keystrokes. It's useful where pasting is blocked or unavailable, such as VM and remote consoles
or fields that block paste.

- Press **⌃⌥⌘T** (configurable) to type the clipboard. Press it again to stop.
- The menu-bar icon turns green while typing.
- Click the icon to open Settings. Closing the window leaves the app running; use **Quit
  macatat** in that window to exit.

## Build and install

Requires macOS 14+ and the Swift 6 toolchain (the Command Line Tools are enough).

```sh
just cert     # one-time: create a local code-signing identity (asks for your password)
just install  # build, copy to /Applications/macatat.app (replacing it), launch
```

On first launch, grant macatat **Accessibility** access in System Settings → Privacy &
Security. Because the cert gives builds a stable signature, the permission stays valid across
reinstalls. Without the cert, builds are signed ad-hoc. Each ad-hoc build has a different
signature, so `just install` resets the permission and macOS asks again.

Other recipes: `just build` (only builds `.build/app/macatat.app`), `just run`, `just test`,
`just clean`.

## Settings

| Setting | Default | |
|---|---|---|
| Type clipboard | ⌃⌥⌘T | Click to record a new shortcut; Esc cancels. Needs ⌃, ⌥ or ⌘. |
| Send newlines with | none | Modifiers held with Return, e.g. ⇧ so chat apps insert a line break instead of sending. |
| Extended characters | Unicode-inject | What to do with characters the current keyboard layout can't type (see below). |
| Inter-key delay | 0.015 s | Pause between keystrokes. |
| Key-up delay | 0.005 s | How long each key is held. |

Characters are mapped to keystrokes using the **current keyboard layout**, so `é` is a single
keystroke on a French layout but an "extended" character on U.S. English. Dead-key
combinations aren't used. For extended characters, you can choose:

- **Unicode-inject**: send the character as text attached to a key event. Works in native Mac
  apps, usually not in VMs or remote desktops.
- **Transliterate to ASCII**: type the closest ASCII spelling (`é`→`e`, `“`→`"`, `—`→`-`) and
  drop characters that have none.
- **Skip**: drop them.
- **Refuse to type**: beep and type nothing if any are present.

Each keystroke presses its modifier keys explicitly and carries both the physical keycode and
the intended character. Native apps receive the exact character, and keycode-based targets
(VMs, remote desktops) still see real key presses.
