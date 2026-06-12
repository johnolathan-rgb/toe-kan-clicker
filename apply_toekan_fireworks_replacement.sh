#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="${1:-/home/johnathan/Desktop/gptcode/toekan-clicker-deployable}"
SOURCE_HTML="${2:-/home/johnathan/Desktop/code/fireworks.html}"

log() { printf '\n[TOEKAN] %s\n' "$*"; }
fail() { printf '\n[TOEKAN ERROR] %s\n' "$*" >&2; exit 1; }

[[ -d "$PROJECT_ROOT" ]] || fail "Project root not found: $PROJECT_ROOT"
[[ -f "$SOURCE_HTML" ]] || fail "Replacement source file not found: $SOURCE_HTML"
[[ "$PROJECT_ROOT" != "$SOURCE_HTML" ]] || fail "Source and project root cannot be the same path."
[[ "$SOURCE_HTML" != "$PROJECT_ROOT/fireworks.html" ]] || fail "Source is already the target file; refusing to overwrite itself."

cd "$PROJECT_ROOT"
[[ -f package.json ]] || fail "package.json missing in $PROJECT_ROOT"
[[ -f main.js ]] || fail "main.js missing in $PROJECT_ROOT"
[[ -f preload.js ]] || fail "preload.js missing in $PROJECT_ROOT"
[[ -f scripts/check.js ]] || fail "scripts/check.js missing in $PROJECT_ROOT"

log "Copying replacement fireworks.html into project. Source will not be modified."
cp -f "$SOURCE_HTML" "$PROJECT_ROOT/fireworks.html"

log "Enforcing package.json start script exactly."
node <<'NODE'
const fs = require('fs');
const pkgPath = 'package.json';
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
pkg.scripts = pkg.scripts || {};
pkg.scripts.start = 'env -u ELECTRON_RUN_AS_NODE electron .';
fs.writeFileSync(pkgPath, `${JSON.stringify(pkg, null, 2)}\n`);
NODE

log "Ensuring main.js loads ./fireworks.html from the same directory."
node <<'NODE'
const fs = require('fs');
const path = 'main.js';
let src = fs.readFileSync(path, 'utf8');

if (!/require\(['"]path['"]\)/.test(src)) {
  src = src.replace(/(const\s*\{[^\n]*\}\s*=\s*require\(['"]electron['"]\);?\s*)/, `$1\nconst path = require('path');\n`);
}

const loadLine = "win.loadFile(path.join(__dirname, 'fireworks.html'));";
if (/win\.loadFile\s*\(/.test(src)) {
  src = src.replace(/win\.loadFile\s*\([\s\S]*?\)\s*;/, loadLine);
} else if (/new\s+BrowserWindow\s*\(/.test(src)) {
  src = src.replace(/(\}\s*\);\s*)(\n\s*}\s*)/, `$1\n  ${loadLine}\n$2`);
} else {
  throw new Error('Could not find BrowserWindow/loadFile location in main.js. Please inspect main.js manually.');
}

fs.writeFileSync(path, src);
NODE

log "Ensuring preload.js exposes window.ToekanShell.quit()."
cat > preload.js <<'JS'
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('ToekanShell', {
  quit: () => ipcRenderer.send('toekan:quit')
});
JS

log "Ensuring main.js has the quit IPC handler."
node <<'NODE'
const fs = require('fs');
const path = 'main.js';
let src = fs.readFileSync(path, 'utf8');

if (!/ipcMain/.test(src)) {
  src = src.replace(/const\s*\{\s*([^}]+)\s*\}\s*=\s*require\(['"]electron['"]\);/, (m, names) => {
    const clean = names.split(',').map(s => s.trim()).filter(Boolean);
    if (!clean.includes('ipcMain')) clean.push('ipcMain');
    return `const { ${clean.join(', ')} } = require('electron');`;
  });
}

if (!/ipcMain\.on\(['"]toekan:quit['"]/.test(src)) {
  const insert = "\nipcMain.on('toekan:quit', () => app.quit());\n";
  if (/app\.whenReady\(\)\.then\(createWindow\);/.test(src)) {
    src = src.replace(/app\.whenReady\(\)\.then\(createWindow\);/, `app.whenReady().then(createWindow);\n${insert}`);
  } else {
    src += insert;
  }
}

fs.writeFileSync(path, src);
NODE

log "Ensuring fireworks.html uses window.ToekanShell.quit() for Quit/Escape."
node <<'NODE'
const fs = require('fs');
const file = 'fireworks.html';
let html = fs.readFileSync(file, 'utf8');

const bridgeScript = String.raw`
<script id="toekan-shell-quit-bridge">
(() => {
  const shellQuit = () => {
    if (window.ToekanShell && typeof window.ToekanShell.quit === 'function') {
      window.ToekanShell.quit();
    }
  };

  window.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') shellQuit();
  });

  window.addEventListener('DOMContentLoaded', () => {
    const controls = Array.from(document.querySelectorAll('button, a, [role="button"], [data-action], [data-toekan-quit]'));
    const quitControls = controls.filter((el) => {
      const text = [el.id || '', el.className || '', el.getAttribute('aria-label') || '', el.getAttribute('title') || '', el.textContent || '', el.getAttribute('data-action') || ''].join(' ');
      return /\\b(quit|exit|close)\\b/i.test(text);
    });

    if (quitControls.length === 0) {
      const button = document.createElement('button');
      button.type = 'button';
      button.textContent = 'Quit';
      button.setAttribute('data-toekan-quit', 'true');
      button.setAttribute('aria-label', 'Quit Toe-Kan Clicker');
      button.style.cssText = 'position:fixed;right:16px;top:16px;z-index:99999;padding:9px 13px;border-radius:12px;border:1px solid rgba(255,255,255,.35);background:rgba(0,0,0,.45);color:white;font:600 14px system-ui,sans-serif;cursor:pointer;backdrop-filter:blur(8px);';
      document.body.appendChild(button);
      quitControls.push(button);
    }

    for (const el of quitControls) {
      el.addEventListener('click', (event) => {
        event.preventDefault();
        shellQuit();
      });
    }
  });
})();
</script>`;

if (!html.includes('toekan-shell-quit-bridge') && !html.includes('window.ToekanShell.quit')) {
  if (/<\/body>/i.test(html)) {
    html = html.replace(/<\/body>/i, `${bridgeScript}\n</body>`);
  } else {
    html += `\n${bridgeScript}\n`;
  }
}

fs.writeFileSync(file, html);
NODE

log "Scanning fireworks.html for missing local asset references."
node <<'NODE'
const fs = require('fs');
const path = require('path');
const html = fs.readFileSync('fireworks.html', 'utf8');
const refs = new Set();
const attrRe = /\b(?:src|href)\s*=\s*["']([^"']+)["']/gi;
const cssRe = /url\(\s*["']?([^"')]+)["']?\s*\)/gi;
const importRe = /(?:import\s+(?:[^'";]+\s+from\s+)?|import\s*\()\s*["']([^"']+)["']/gi;
for (const re of [attrRe, cssRe, importRe]) {
  let m;
  while ((m = re.exec(html))) refs.add(m[1]);
}
const missing = [];
for (const raw of refs) {
  const ref = raw.split('#')[0].split('?')[0].trim();
  if (!ref || ref.startsWith('#')) continue;
  if (/^(?:https?:|data:|blob:|mailto:|javascript:|about:)/i.test(ref)) continue;
  if (ref.startsWith('/')) {
    const local = path.join(process.cwd(), ref.replace(/^\/+/, ''));
    if (!fs.existsSync(local)) missing.push(raw);
    continue;
  }
  if (!fs.existsSync(path.join(process.cwd(), ref))) missing.push(raw);
}
if (missing.length) {
  console.error('\nMissing local references in fireworks.html:');
  for (const ref of missing) console.error(` - ${ref}`);
  console.error('\nFix these paths/files, then rerun npm run check.');
  process.exit(1);
}
console.log('No missing local file references found.');
NODE

log "Running npm run check."
npm run check

log "Done. Project is ready for npm start / npm run dist:steam-linux."
