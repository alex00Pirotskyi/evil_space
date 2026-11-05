import assert from 'node:assert/strict';
import { access, mkdir, mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import { buildSeo } from '../tool/build_seo.mjs';
import { seoResponse } from '../worker/seo_pages.js';
import { landingPages, SEO_ORIGIN, SEO_MAP_URL } from '../seo/pages.mjs';

let output;
before(async () => {
  output = await mkdtemp(path.join(os.tmpdir(), 'evil-seo-'));
  await mkdir(path.join(output, 'en', 'pricing'), {recursive: true});
  await writeFile(path.join(output, 'en', 'index.html'), 'old localized page');
  await writeFile(path.join(output, 'en', 'pricing', 'index.html'), 'old price page');
  await buildSeo(output);
});
after(async () => { if (output) await rm(output, {recursive: true, force: true}); });

test('Flutter booking app remains root canonical and links to every language', async () => {
  const index = await readFile(path.join(import.meta.dirname, '..', 'web', 'index.html'), 'utf8');
  const app = await readFile(path.join(import.meta.dirname, '..', 'lib', 'main.dart'), 'utf8');
  assert.match(index, /<title>Evil Space \| Coworking Space in Nha Trang<\/title>/);
  assert.ok(app.includes("title: 'Evil Space | Coworking Space in Nha Trang'"));
  assert.ok(!app.includes('SemanticsBinding.instance.ensureSemantics()'));
  assert.match(index, /<link rel="canonical" href="https:\/\/evils\.space\/">/);
  assert.match(index, /<meta name="robots" content="index,follow">/);
  assert.ok(index.includes('href="manifest.json"'));
  assert.ok(index.includes('src="flutter_bootstrap.js"'));
  assert.ok(index.includes('id="evil-space-boot"'));
  for (const page of landingPages) {
    assert.ok(index.includes('href="' + page.path + '"'), 'Native root link missing: ' + page.lang);
    assert.ok(index.includes('hreflang="' + page.lang + '" href="' + SEO_ORIGIN + page.path + '"'));
  }
  assert.ok(index.includes('hreflang="x-default" href="https://evils.space/"'));

  const json = index.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)?.[1];
  const business = JSON.parse(json);
  assert.equal(business.url, SEO_ORIGIN + '/');
  assert.ok(business.amenityFeature.every(feature =>
    feature['@type'] === 'LocationFeatureSpecification' && feature.value === true));
  assert.ok(business.amenityFeature.some(feature => feature.name === 'Coffee bar'));
  assert.equal(business.openingHoursSpecification[0].opens, '10:00');
  assert.equal(business.openingHoursSpecification[0].closes, '23:00');
  assert.deepEqual(business.openingHoursSpecification[0].dayOfWeek,
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']);
});

test('localized guides are real, useful, accessible HTML with reciprocal hreflang', async () => {
  const all = [...landingPages.map(page => [page.lang, SEO_ORIGIN + page.path]), ['x-default', SEO_ORIGIN + '/']];
  for (const page of landingPages) {
    const filename = path.join(output, page.lang, page.slug, 'index.html');
    const html = await readFile(filename, 'utf8');
    assert.ok(html.length > 2500, 'Expected substantial page text, not a thin doorway page');
    assert.ok(html.includes('<html lang="' + page.lang + '">'));
    assert.ok(html.includes('<title>' + page.title + '</title>') ||
      html.includes('<title>' + page.title.replaceAll('&','&amp;') + '</title>'));
    assert.ok(html.includes('<link rel="canonical" href="' + SEO_ORIGIN + page.path + '">'));
    assert.ok(html.includes('<meta name="robots" content="index,follow">'));
    assert.ok(html.includes('<h1 id="main-title">' + page.heading + '</h1>'));
    assert.ok(html.includes('href="/"') && html.includes('href="/seo/site.css"'));
    assert.ok(html.includes('href="tel:+84565056748"'));
    assert.ok(html.includes('60 Cao Văn Bé'));
    assert.ok(html.includes('10:00') && html.includes('23:00'));
    assert.ok(html.includes('href="' + SEO_MAP_URL + '"'), 'Google Maps photos/reviews link missing');
    assert.ok(!html.includes('flutter_bootstrap.js'));
    for (const [lang, href] of all) {
      assert.ok(html.includes('hreflang="' + lang + '" href="' + href + '"'),
        page.lang + ' is missing alternate ' + lang);
    }
    const schema = html.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)?.[1];
    const parsed = JSON.parse(schema);
    assert.equal(parsed['@type'], 'WebPage');
    assert.equal(parsed.url, SEO_ORIGIN + page.path);
    assert.equal(parsed.inLanguage, page.lang);
    assert.equal(parsed.about['@id'], SEO_ORIGIN + '/#business');
    // The guide may link out for authentic photos but must not claim false ratings.
    assert.ok(!html.includes('aggregateRating'));
  }
  const css = await readFile(path.join(output, 'seo/site.css'), 'utf8');
  assert.ok(css.includes('--paper:#f2f0e8'));
  assert.ok((await readFile(path.join(output, 'seo/share.png'))).length > 1000);
  await assert.rejects(access(path.join(output, 'en', 'pricing')));
  await assert.rejects(access(path.join(output, 'en', 'index.html')));
});

test('sitemap includes the booking homepage and exactly three language guides', async () => {
  const xml = await readFile(path.join(output, 'sitemap.xml'), 'utf8');
  const expected = [SEO_ORIGIN + '/', ...landingPages.map(page => SEO_ORIGIN + page.path)];
  assert.deepEqual([...xml.matchAll(/<loc>([^<]+)<\/loc>/g)].map(match => match[1]), expected);
  assert.equal((xml.match(/<url>/g) ?? []).length, expected.length);
  assert.equal((xml.match(/hreflang="x-default"/g) ?? []).length, expected.length);
  for (const page of landingPages) {
    assert.equal((xml.match(new RegExp('hreflang="' + page.lang + '"', 'g')) ?? []).length,
      expected.length);
  }
  const robots = await readFile(path.join(output, 'robots.txt'), 'utf8');
  assert.match(robots, /^User-agent: \*\nAllow: \/\n/m);
  assert.match(robots, /Sitemap: https:\/\/evils\.space\/sitemap\.xml/);
});

test('SEO guide routing handles GET/HEAD, canonical aliases and old redirects', async () => {
  const assetPaths = [];
  const env = { ASSETS: { fetch: async (request) => {
    assetPaths.push(new URL(request.url).pathname);
    return new Response('ACTUAL PAGE', {status: 200,
      headers: {'Content-Type': 'text/html; charset=utf-8'}});
  }}};
  for (const page of landingPages) {
    const canonical = SEO_ORIGIN + page.path;
    const response = await seoResponse(new Request(canonical), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('content-type'), 'text/html; charset=utf-8');
    assert.equal(await response.text(), 'ACTUAL PAGE');
    assert.ok(!response.headers.get('x-robots-tag')?.includes('noindex'));
    for (const alias of [page.path.slice(0, -1), page.path + 'index.html']) {
      const redirect = await seoResponse(new Request(SEO_ORIGIN + alias), env);
      assert.equal(redirect.status, 301);
      assert.equal(redirect.headers.get('location'), canonical);
    }
    const head = await seoResponse(new Request(canonical, {method: 'HEAD'}), env);
    assert.equal(head.status, 200);
    assert.equal(await head.text(), '');
    const post = await seoResponse(new Request(canonical, {method: 'POST'}), env);
    assert.equal(post.status, 405);
  }
  for (const lang of ['en', 'ru', 'vi']) {
    for (const retired of ['', '/', '/pricing', '/pricing/', '/visit', '/visit/']) {
      const response = await seoResponse(new Request(SEO_ORIGIN + '/' + lang + retired), env);
      assert.equal(response.status, 301);
      assert.equal(response.headers.get('location'), SEO_ORIGIN + '/');
    }
    const unknown = await seoResponse(new Request(SEO_ORIGIN + '/' + lang + '/made-up-page'), env);
    assert.equal(unknown.status, 404);
    assert.equal(unknown.headers.get('x-robots-tag'), 'noindex');
  }
  for (const route of ['/admin', '/admin/menu', '/menu', '/menu/', '/qr', '/qr/']) {
    const response = await seoResponse(new Request(SEO_ORIGIN + route), env);
    assert.equal(response.status, 200);
    assert.equal(response.headers.get('x-robots-tag'), 'noindex, follow');
  }
  assert.deepEqual(assetPaths.slice(0, 6), landingPages.flatMap(page => [page.path, page.path]));
  assert.deepEqual(assetPaths.slice(6), Array(6).fill('/'));
  const config = await readFile(path.join(import.meta.dirname, '..', 'wrangler.toml'), 'utf8');
  assert.match(config, /not_found_handling = "404-page"/);
  for (const lang of ['en', 'ru', 'vi']) assert.ok(config.includes('"/' + lang + '/*"'));
  assert.match(config, /"\/menu\/\*"/);
  assert.match(config, /"\/qr\/\*"/);
  assert.equal(await seoResponse(new Request(SEO_ORIGIN + '/api/health'), env), null);
});
