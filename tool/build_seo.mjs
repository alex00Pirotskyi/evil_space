import { copyFile, mkdir, rm, writeFile } from 'node:fs/promises';

import path from 'node:path';

import { fileURLToPath } from 'node:url';

import { landingPages, SEO_ORIGIN, SEO_MAP_URL, SEO_DIRECTIONS_URL, SEO_INSTAGRAM_URL } from '../seo/pages.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function escapeHtml(value) {
  return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

function seoAlternates() {
  return [
    {lang: 'en', href: SEO_ORIGIN + landingPages[0].path},
    {lang: 'ru', href: SEO_ORIGIN + landingPages[1].path},
    {lang: 'vi', href: SEO_ORIGIN + landingPages[2].path},
    {lang: 'x-default', href: SEO_ORIGIN + '/'},
  ];
}

function renderLandingPage(page) {
  const esc = escapeHtml;
  const canonical = SEO_ORIGIN + page.path;
  const alternates = seoAlternates().map(({lang,href}) =>
    `<link rel="alternate" hreflang="${lang}" href="${esc(href)}">`).join('\n  ');
  const langLinks = landingPages.map((candidate) =>
    `<a href="${esc(candidate.path)}"${candidate.lang === page.lang ? ' aria-current="page"' : ''}>${esc(candidate.navLabel)}</a>`
  ).join('\n        ');
  const features = page.features.map((label) => `<li>${esc(label)}</li>`).join('\n          ');
  const steps = page.steps.map((label) => `<li>${esc(label)}</li>`).join('\n          ');
  const faq = page.faq.map(([question, answer]) => `<article><h3>${esc(question)}</h3><p>${esc(answer)}</p></article>`).join('\n        ');
  const schema = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    '@id': canonical + '#webpage',
    url: canonical,
    name: page.title,
    description: page.description,
    inLanguage: page.lang,
    about: { '@id': SEO_ORIGIN + '/#business' },
  }).replace(/</g, '\\u003c');
  const hourLine = {
    en: 'MON–FRI 10:00–23:00 · WEEKENDS CLOSED',
    ru: 'ПН–ПТ 10:00–23:00 · СБ–ВС ЗАКРЫТО',
    vi: 'THỨ 2–6 10:00–23:00 · THỨ 7–CN NGHỈ',
  }[page.lang];
  return `<!DOCTYPE html>
<html lang="${esc(page.lang)}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#F2F0E8">
  <meta name="robots" content="index,follow">
  <meta name="description" content="${esc(page.description)}">
  <title>${esc(page.title)}</title>
  <link rel="canonical" href="${esc(canonical)}">
  ${alternates}
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/seo/site.css">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Evil Space">
  <meta property="og:locale" content="${{en:'en_US',ru:'ru_RU',vi:'vi_VN'}[page.lang]}">
  <meta property="og:title" content="${esc(page.title)}">
  <meta property="og:description" content="${esc(page.description)}">
  <meta property="og:url" content="${esc(canonical)}">
  <meta property="og:image" content="${SEO_ORIGIN}/seo/share.png">
  <meta name="twitter:card" content="summary_large_image">
  <script type="application/ld+json">${schema}</script>
</head>
<body>
  <header class="site-header">
    <div class="wrap topbar">
      <a class="brand" href="/" aria-label="Evil Space home">EVIL SPACE</a>
      <nav class="lang-nav" aria-label="Language">
        ${langLinks}
      </nav>
    </div>
  </header>
  <main class="wrap">
    <nav class="breadcrumb" aria-label="Breadcrumb">
      <a href="/">EVIL SPACE</a><span aria-hidden="true">/</span><span>${esc(page.kicker)}</span>
    </nav>
    <section class="hero" aria-labelledby="main-title">
      <div class="eyebrow">${esc(page.kicker)}</div>
      <h1 id="main-title">${esc(page.heading)}</h1>
      <p class="lead">${esc(page.lead)}</p>
      <div class="actions">
        <a class="btn primary" href="/">${esc(page.bookLabel)}</a>
        <a class="btn secondary" href="${esc(SEO_MAP_URL)}" rel="noopener noreferrer" target="_blank">${esc(page.mapsLabel)}</a>
      </div>
      <ul class="facts">
        <li>${esc(hourLine)}</li>
        <li>DAY PASS 200K VND</li>
        <li>MONTHLY 2.5M VND</li>
      </ul>
    </section>
    <div class="content">
      <div>
        <article class="article-block">
          <p class="section-label">01 / EVIL SPACE</p>
          <h2>${esc(page.workTitle)}</h2>
          <p>${esc(page.workText)}</p>
        </article>
        <article class="article-block">
          <p class="section-label">02 / PRICING</p>
          <h2>${esc(page.pricesTitle)}</h2>
          <p>${esc(page.pricesText)}</p>
          <p class="note">${esc(page.note)}</p>
        </article>
        <article class="article-block">
          <p class="section-label">03 / LOCATION</p>
          <h2>${esc(page.directionsTitle)}</h2>
          <p>${esc(page.directionsText)}</p>
          <address>60 Cao Văn Bé, Vĩnh Phước, Nha Trang, Khánh Hòa, Việt Nam</address>
          <p><a href="${esc(SEO_DIRECTIONS_URL)}" rel="noopener noreferrer" target="_blank">${esc(page.directionsLabel)}</a> · <a href="tel:+84565056748">+84 56 5056 748</a></p>
        </article>
      </div>
      <aside>
        <div class="side-box">
          <p class="section-label">04 / FEATURES</p>
          <h2>${esc(page.featuresTitle)}</h2>
          <ul class="feature-list">${features}</ul>
        </div>
        <div class="side-box">
          <p class="section-label">05 / BOOKING</p>
          <h2>${esc(page.stepsTitle)}</h2>
          <ol class="numbered">${steps}</ol>
          <p><a class="btn primary" href="/">${esc(page.bookLabel)}</a></p>
        </div>
      </aside>
    </div>
    <section class="faq" aria-labelledby="faq-heading">
      <p class="section-label">06 / FAQ</p>
      <h2 id="faq-heading">${esc(page.faqTitle)}</h2>
      <div class="faq-grid">${faq}</div>
    </section>
  </main>
  <footer>
    <div class="wrap footer">
      <span>${esc(page.footerLabel)} · 60 Cao Văn Bé</span>
      <div class="footer-links">
        <a href="/">${esc(page.homeLabel)}</a>
        <a href="${esc(SEO_INSTAGRAM_URL)}" rel="noopener noreferrer" target="_blank">${esc(page.instagramLabel)}</a>
        <a href="${esc(SEO_MAP_URL)}" rel="noopener noreferrer" target="_blank">GOOGLE MAPS</a>
      </div>
    </div>
  </footer>
</body>
</html>
`;
}

function renderSitemap() {
  const urls = [SEO_ORIGIN + '/', ...landingPages.map(page => SEO_ORIGIN + page.path)];
  const alternates = seoAlternates().map(({lang,href}) =>
    `    <xhtml:link rel="alternate" hreflang="${lang}" href="${escapeHtml(href)}"/>`).join('\n');
  return '<?xml version="1.0" encoding="UTF-8"?>\n' +
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n' +
    urls.map(url => `  <url>\n    <loc>${escapeHtml(url)}</loc>\n${alternates}\n  </url>`).join('\n') +
    '\n</urlset>\n';
}

export async function buildSeo(outputDir = path.join(root, 'build', 'web')) {
  await mkdir(outputDir, {recursive: true});
  // Rebuild language directories from verified content, removing obsolete files.
  for (const lang of ['en', 'ru', 'vi']) {
    await rm(path.join(outputDir, lang), {recursive: true, force: true});
  }
  await mkdir(path.join(outputDir, 'seo'), {recursive: true});
  await copyFile(path.join(root, 'seo', 'share.png'), path.join(outputDir, 'seo', 'share.png'));
  await copyFile(path.join(root, 'seo', 'site.css'), path.join(outputDir, 'seo', 'site.css'));
  for (const page of landingPages) {
    const dir = path.join(outputDir, page.lang, page.slug);
    await mkdir(dir, {recursive: true});
    await writeFile(path.join(dir, 'index.html'), renderLandingPage(page), 'utf8');
  }
  await writeFile(path.join(outputDir, 'robots.txt'),
    `User-agent: *\nAllow: /\n\nSitemap: ${SEO_ORIGIN}/sitemap.xml\n`, 'utf8');
  await writeFile(path.join(outputDir, 'sitemap.xml'), renderSitemap(), 'utf8');
  console.log('SEO: built root + three crawlable language pages, sitemap, robots and share image');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {

  await buildSeo(process.argv[2] ? path.resolve(process.argv[2]) : undefined);

}

