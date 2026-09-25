import assert from 'node:assert/strict';
import { readFile, mkdtemp, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { buildSeo, pageUrl } from '../tool/build_seo.mjs';
import { seoResponse } from '../worker/seo_pages.js';
import { business, languages } from '../seo/content.mjs';

let output;
before(async () => {
  output = await mkdtemp(path.join(os.tmpdir(), 'evil-seo-'));
  await buildSeo(output);
});
after(async () => { if (output) await rm(output, { recursive: true, force: true }); });

const pages = { home: '', pricing: 'pricing/', visit: 'visit/' };

test('each localized page has readable business content and complete reciprocal language links', async () => {
  for (const lang of Object.keys(languages)) {
    for (const [page, slug] of Object.entries(pages)) {
      const html = await readFile(path.join(output, lang, slug, 'index.html'), 'utf8');
      assert.match(html, new RegExp(`<html lang="${lang}">`));
      assert.match(html, /<h1 id="page-heading">[^<]+<\/h1>/);
      assert.match(html, /<meta name="description" content="[^"]+">/);
      assert.ok(html.includes(`<link rel="canonical" href="${pageUrl(lang, page)}">`));
      assert.ok(html.includes('60 Cao Văn Bé'));
      assert.ok(html.includes(`href="/?lang=${lang}"`));
      assert.ok(!html.includes('undefined'));
      assert.ok(!html.includes('250K VND'));
      assert.ok(!html.includes('53/14 Cao Văn Bé'));
      for (const other of Object.keys(languages)) {
        assert.ok(html.includes(`rel="alternate" hreflang="${other}" href="${pageUrl(other, page)}"`));
      }
      assert.ok(html.includes(`rel="alternate" hreflang="x-default" href="${pageUrl('en', page)}"`));
      const json = html.match(/<script type="application\/ld\+json">([^<]+)<\/script>/)?.[1];
      const graph = JSON.parse(json)['@graph'];
      assert.equal(graph[0].address.streetAddress, `${business.street}, ${business.ward}`);
      assert.equal(graph[0].telephone, business.phone);
      assert.equal(graph[0].priceRange, '200K VND day / 2.5M VND month');
      assert.equal(graph[1].inLanguage, lang);
      for (const other of Object.keys(pages)) {
        if (other !== page) {
          assert.ok(html.includes(`class="related-card" href="${pageUrl(lang, other)}"`));
        }
      }
      if (page !== 'home') {
        assert.equal(graph[1].breadcrumb['@id'], `${pageUrl(lang, page)}#breadcrumbs`);
        assert.deepEqual(graph[2].itemListElement.map(({ item }) => item), [pageUrl(lang, 'home'), pageUrl(lang, page)]);
        assert.ok(html.includes(`class="breadcrumbs" aria-label="${languages[lang].common.breadcrumbs}"`));
      }
    }
  }
});

test('booking app remains an installable Flutter app and links all language pages', async () => {
  const index = await readFile(path.join(import.meta.dirname, '..', 'web', 'index.html'), 'utf8');
  assert.ok(index.includes('href="manifest.json"'));
  assert.ok(index.includes('src="flutter_bootstrap.js"'));
  assert.ok(index.includes('id="evil-space-boot"'));
  for (const lang of Object.keys(languages)) {
    assert.ok(index.includes(`href="/${lang}/"`));
  }
  const json = index.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)?.[1];
  assert.equal(JSON.parse(json)['@id'], `${business.origin}/#business`);
});

test('the sitemap includes the booking app and nine localized pages and robots points to it', async () => {
  const xml = await readFile(path.join(output, 'sitemap.xml'), 'utf8');
  const locs = [...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map((m) => m[1]);
  const expected = [
    `${business.origin}/`,
    ...Object.keys(languages).flatMap((lang) =>
      Object.keys(pages).map((page) => pageUrl(lang, page))),
  ];
  assert.deepEqual(locs, expected);
  const robots = await readFile(path.join(output, 'robots.txt'), 'utf8');
  assert.match(robots, /^User-agent: \*\nAllow: \/\n/m);
  assert.match(robots, /Sitemap: https:\/\/evils\.space\/sitemap\.xml/);
  assert.ok((await readFile(path.join(output, 'seo/share.png'))).length > 1000);
});

test('language routes serve pages, redirect to canonical slashes, and reject nonexistent pages', async () => {
  const fetched = [];
  const env = { ASSETS: { fetch: async (request) => {
    const pathname = new URL(request.url).pathname;
    fetched.push(pathname);
    if (pathname === '/admin' || pathname === '/menu' || pathname === '/qr') {
      return new Response('Flutter app', { headers: { 'Content-Type': 'text/html' } });
    }
    const html = await readFile(path.join(output, pathname, 'index.html'), 'utf8');
    return new Response(html, { headers: { 'Content-Type': 'text/html' } });
  } } };

  for (const lang of Object.keys(languages)) {
    const url = `https://evils.space/${lang}/pricing/`;
    const res = await seoResponse(new Request(url), env);
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-language'), lang);
    assert.match(await res.text(), /<h1/);
    const redirect = await seoResponse(new Request(url.slice(0, -1)), env);
    assert.equal(redirect.status, 308);
    assert.equal(redirect.headers.get('location'), url);
    assert.equal((await seoResponse(new Request(`https://evils.space/${lang}/`), env)).status, 200);
    const missing = await seoResponse(new Request(`https://evils.space/${lang}/made-up-page`), env);
    assert.equal(missing.status, 404);
    assert.equal(missing.headers.get('x-robots-tag'), 'noindex');
  }
  assert.ok(!fetched.includes('/en/made-up-page'));
  assert.equal((await seoResponse(new Request('https://evils.space/admin'), env)).headers.get('x-robots-tag'), 'noindex, follow');
  assert.equal(await seoResponse(new Request('https://evils.space/api/health'), env), null);
});
