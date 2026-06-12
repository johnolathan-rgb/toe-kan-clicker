# Hermes task: replace Toe-Kan Clicker fireworks.html and validate

Run this from the unpacked handoff folder:

```bash
./apply_toekan_fireworks_replacement.sh
```

Default paths used by the script:

- Project root: `/home/johnathan/Desktop/gptcode/toekan-clicker-deployable`
- Replacement source: `/home/johnathan/Desktop/code/fireworks.html`

The script must **not** modify `/home/johnathan/Desktop/code/fireworks.html`. It only copies that file into the project as `fireworks.html`, then enforces/checks:

1. `package.json` start script is exactly `env -u ELECTRON_RUN_AS_NODE electron .`
2. `main.js` loads `fireworks.html` from the same directory.
3. `preload.js` exposes `window.ToekanShell.quit()`.
4. `fireworks.html` uses `window.ToekanShell.quit()` for Quit/Escape.
5. Missing local asset references in `fireworks.html` are reported.
6. `npm run check` passes.

If the script reports missing references from `fireworks.html`, update those references/files inside `/home/johnathan/Desktop/gptcode/toekan-clicker-deployable` only, then rerun:

```bash
npm run check
```

Then test:

```bash
npm start
```

For Steam/Linux depot:

```bash
npm run dist:steam-linux
```
