# Contributing

Bug reports, ideas and pull requests are welcome.

## Reporting a bug

Open an [issue](https://github.com/galaxysochi-code/LayoutFixer/issues) and include:

- macOS version and Mac model;
- the app version (settings window → General → About);
- your keyboard layouts and the dictionaries you enabled;
- what you typed, what happened and what you expected;
- the verdict from the **Проверка** (Check) tab for the word in question — it explains the app's
  decision without you having to reproduce anything.

## Pull requests

- Build with `./build.sh` and try the change on a real keyboard before opening the PR.
- Keep the code in the style of the surrounding sources: comments in Russian, no third-party
  dependencies, no new build tooling.
- **Never add anything that stores typed text**, and never add networking. Both are deal breakers,
  whatever the benefit — see [PRIVACY.md](PRIVACY.md).
- Anything that runs inside the key-tap thread must not wait on the system (no Accessibility calls,
  no spell checking, no input-source switching, no disk access). A wait there freezes input for the
  whole machine.

## Releasing

```bash
git tag v1.0.2 && git push origin v1.0.2
```

GitHub Actions builds the app and attaches `LayoutFixer.dmg` to the release.
