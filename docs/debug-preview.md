# Evil Space redesign preview

Production stays at `https://evils.space/` on Worker `evil-space` with D1.
The isolated paper redesign uses `lib/main_debug.dart` and a separate static
Worker `evil-space-test` at `https://test.evils.space/`.

## Deploy committed changes

Commit/push the changes to `main`, then run:

```bash
make debug
```

This triggers the **Design preview** GitHub Actions workflow using the existing
Cloudflare Actions secrets. It deploys only `wrangler.debug.toml`; it never
runs production D1 migrations. On Windows use `make.cmd debug`.

The initial successful deploy attaches the Worker Custom Domain. Cloudflare may
need time to provision the certificate/DNS. The token must allow custom domains
for the `evils.space` zone.

## Deploy local unpushed changes

```bash
make debug-local
```

Requires Flutter 3.47.2+, Node and authenticated Wrangler on your computer.
For a build without deployment use `make debug-build`.

## Edit the design

- `shaders/paper_shader.frag`: uploaded black paper fragment shader.
- `lib/premium_paper_widget.dart`: full-screen Flutter renderer with pointer light.
- `lib/main_debug.dart`: empty staging entry point.
- `tool/prepare_debug_web.mjs`: dark empty HTML, isolated bootstrap, noindex headers.
- `wrangler.debug.toml`: static-only Worker and staging domain.

`make` and `make deploy` still release the existing production app.
