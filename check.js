const fs = require('fs');
const vm = require('vm');

const html = fs.readFileSync('fireworks.html', 'utf8');
const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);

if (!scriptMatch) {
  throw new Error('fireworks.html is missing its inline script');
}

new vm.Script(scriptMatch[1], { filename: 'fireworks.html' });
console.log('fireworks.html inline script syntax OK');
