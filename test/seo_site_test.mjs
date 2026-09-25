import assert from 'node:assert/strict';
import { access, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { buildSeo } from '../tool/build_seo.mjs';
import { seoResponse } from '../worker/seo_pages.js';

let output;
before(async () => {
  output = await mkdtemp(path.join(os.tmpdir(), 'evil-seo-'));
  await mkdir(path.join(output, 'en'), { recursive: true });
  await writeFile(path.join(output, 'en', 'index.html'), 'old localized page');
  await buildSeo(output);
});
after(async () => { if (output) await rm(output, { recursive: true, force: true }); });

test('Flutter app stays indexable at the only canonical public URL', async () => {
  const index = await readFile(path.join(import.meta.dirname, '..', 'web', 'index.html'), 'utf8');
  const app = await readFile(path.join(import.meta.dirname, '..', 'lib', 'main.dart'), 'utf8');
  assert.match(index, /<title>Evil Space \| Coworking Space in Nha Trang<\/title>/);
  assert.ok(app.includes("title: 'Evil Space | Coworking Space in Nha Trang'"));
  assert.match(index, /<link rel="canonical" href="https:\/\/evils\.space\/">/);
  assert.match(index, /<meta name="robots" content="index,follow">/);
  assert.ok(index.includes('href="manifest.json"'));
  assert.ok(index.includes('src="flutter_bootstrap.js"'));
  assert.ok(index.includes('id="evil-space-boot"'));
  assert.ok(!/href="\/(en|ru|vi)\//.test(index));
  const json = index.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)?.[1];
  assert.equal(JSON.parse(json).url, 'https://evils.space/');
});

test('sitemap lists only the root and the build removes old localized pages', async () => {
  const xml = await readFile(path.join(output, 'sitemap.xml'), 'utf8');
  assert.deepEqual([...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]), ['https://evils.space/']);
  for (const lang of ['en', 'ru', 'vi']) {
    await assert.rejects(access(path.join(output, lang)));
  }
  const robots = await readFile(path.join(output, 'robots.txt'), 'utf8');
  assert.match(robots, /^User-agent: \*\nAllow: \/\n/m);
  assert.match(robots, /Sitemap: https:\/\/evils\.space\/sitemap\.xml/);
  assert.ok((await readFile(path.join(output, 'seo/share.png'))).length > 1000);
});

test('old page URLs permanently redirect to root, unknown pages return 404', async () => {
  const env = { ASSETS: { fetch: async () => new Response('Flutter app') } };
  for (const lang of ['en', 'ru', 'vi']) {
    for (const slug of ['', '/', '/pricing', '/pricing/', '/visit', '/visit/']) {
      const res = await seoResponse(new Request(`https://evils.space/${lang}${slug}`), env);
      assert.equal(res.status, 301);
      assert.equal(res.headers.get('location'), 'https://evils.space/');
    }
    const unknown = await seoResponse(new Request(`https://evils.space/${lang}/made-up-page`), env);
    assert.equal(unknown.status, 404);
    assert.equal(unknown.headers.get('x-robots-tag'), 'noindex');
  }
  const head = await seoResponse(new Request('https://evils.space/en/', { method: 'HEAD' }), env);
  assert.equal(head.status, 301);
  assert.equal((await seoResponse(new Request('https://evils.space/admin'), env)).headers.get('x-robots-tag'), 'noindex, follow');
  assert.equal(await seoResponse(new Request('https://evils.space/api/health'), env), null);
});
