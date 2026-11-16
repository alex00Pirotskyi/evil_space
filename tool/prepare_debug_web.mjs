import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const output = path.resolve('build/debug_web');
const bootPath = path.join(output, 'flutter_bootstrap.js');
const builtBootstrap = await readFile(bootPath, 'utf8');

// Preserve Flutter's compiled engine/config, remove production boot/status code.
const marker = "const bootElement = document.getElementById('evil-space-boot');";
const markerIndex = builtBootstrap.indexOf(marker);
if (markerIndex < 0 || !builtBootstrap.includes('_flutter.loader.load(')) {
  throw new Error('Unexpected generated bootstrap; staging not prepared.');
}
const isolatedBootstrap = builtBootstrap.slice(0, markerIndex)
  + '\n// Isolated static paper study; no production API prefetch.\n'
  + '_flutter.loader.load();\n';
await writeFile(bootPath, isolatedBootstrap);

await writeFile(path.join(output, 'index.html'), `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
  <meta name="theme-color" content="#050505">
  <meta name="color-scheme" content="dark">
  <meta name="robots" content="noindex,nofollow,noarchive">
  <title>Evil Space — Paper Study</title>
  <style>html,body{width:100%;height:100%;margin:0;overflow:hidden;background:#050505}</style>
  <script src="flutter_bootstrap.js" async></script>
</head>
<body></body>
</html>
`);
await writeFile(path.join(output, 'robots.txt'), 'User-agent: *\nDisallow: /\n');
await writeFile(path.join(output, '_headers'), `/*
  X-Robots-Tag: noindex, nofollow, noarchive
  X-Content-Type-Options: nosniff
  Referrer-Policy: no-referrer
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Embedder-Policy: credentialless

/
  Cache-Control: no-store

/index.html
  Cache-Control: no-store

/flutter_bootstrap.js
  Cache-Control: no-store
`);
if (isolatedBootstrap.includes('/api/public/status')) {
  throw new Error('Production API reference leaked into staging.');
}
console.log('Staging shell ready: no UI, API calls or indexing.');
