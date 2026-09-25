import { copyFile, mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { business, languages } from '../seo/content.mjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
export const slugs = Object.freeze({ home: '', pricing: 'pricing/', visit: 'visit/' });

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (char) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[char]);
}

export function pageUrl(lang, page) {
  return `${business.origin}/${lang}/${slugs[page]}`;
}

function alternateLinks(page) {
  return Object.keys(languages).map((lang) =>
    `<link rel="alternate" hreflang="${lang}" href="${pageUrl(lang, page)}">`,
  ).join('\n  ') +
    `\n  <link rel="alternate" hreflang="x-default" href="${pageUrl('en', page)}">`;
}

function schema(lang, page) {
  const url = pageUrl(lang, page);
  return JSON.stringify({
    '@context': 'https://schema.org',
    '@graph': [
      {
        '@type': 'LocalBusiness',
        '@id': `${business.origin}/#business`,
        name: business.name,
        url: pageUrl('en', 'home'),
        image: `${business.origin}/seo/share.png`,
        telephone: business.phone,
        priceRange: '200K VND day / 2.5M VND month',
        currenciesAccepted: 'VND',
        address: {
          '@type': 'PostalAddress',
          streetAddress: `${business.street}, ${business.ward}`,
          addressLocality: business.city,
          addressRegion: business.region,
          addressCountry: 'VN',
        },
        openingHoursSpecification: [{
          '@type': 'OpeningHoursSpecification',
          dayOfWeek: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
          opens: business.opens,
          closes: business.closes,
        }],
        hasMap: business.maps,
        sameAs: [business.maps, business.instagram],
      },
      {
        '@type': 'WebPage',
        '@id': `${url}#webpage`,
        url,
        inLanguage: lang,
        name: languages[lang].pages[page].title,
        about: { '@id': `${business.origin}/#business` },
        ...(page === 'home' ? {} : { breadcrumb: { '@id': `${url}#breadcrumbs` } }),
      },
      ...(page === 'home' ? [] : [{
        '@type': 'BreadcrumbList',
        '@id': `${url}#breadcrumbs`,
        itemListElement: [
          { '@type': 'ListItem', position: 1, name: languages[lang].common.home, item: pageUrl(lang, 'home') },
          { '@type': 'ListItem', position: 2, name: page === 'pricing' ? languages[lang].common.prices : languages[lang].common.visit, item: url },
        ],
      }]),
    ],
  }).replace(/</g, '\\u003c');
}

function textParagraphs(paragraphs) {
  return paragraphs.map((paragraph) => `<p>${escapeHtml(paragraph)}</p>`).join('\n          ');
}

export function renderPage(lang, page) {
  const locale = languages[lang];
  if (!locale || !Object.hasOwn(slugs, page)) throw new Error(`Unknown SEO page: ${lang}/${page}`);
  const c = locale.common;
  const p = locale.pages[page];
  const url = pageUrl(lang, page);
  const bookingUrl = `/?lang=${lang}`;
  const primaryAction = `<a class="button" href="${bookingUrl}">${escapeHtml(c.book)} <span aria-hidden="true">↗</span></a>`;
  const mapAction = `<a class="button secondary" href="${escapeHtml(business.maps)}">${escapeHtml(c.maps)} <span aria-hidden="true">↗</span></a>`;
  const story = p.sections.map((section) => `
      <section class="story">
        <h3>${escapeHtml(section.heading)}</h3>
        <div class="story-copy">${textParagraphs(section.paragraphs)}</div>
      </section>`).join('');
  const faqs = p.faqs.map((item) => `
      <section class="qa"><h3>${escapeHtml(item.q)}</h3><p>${escapeHtml(item.a)}</p></section>`).join('');
  const nav = Object.entries(slugs).map(([key]) =>
    `<a href="${pageUrl(lang, key)}"${page === key ? ' aria-current="page"' : ''}>${escapeHtml(key === 'pricing' ? c.prices : c[key])}</a>`,
  ).join('\n        ');
  const langNav = Object.entries(languages).map(([code]) =>
    `<a href="${pageUrl(code, page)}" hreflang="${code}" lang="${code}" title="${escapeHtml(languages[code].label)}"${lang === code ? ' aria-current="page"' : ''}>${code.toUpperCase()}</a>`,
  ).join('\n      ');
  const breadcrumbs = page === 'home' ? '' : `
      <nav class="breadcrumbs" aria-label="${escapeHtml(c.breadcrumbs)}">
        <a href="${pageUrl(lang, 'home')}">${escapeHtml(c.home)}</a><span aria-hidden="true">/</span><span aria-current="page">${escapeHtml(page === 'pricing' ? c.prices : c.visit)}</span>
      </nav>`;
  const related = Object.keys(slugs).filter((key) => key !== page).map((key) =>
    `<a class="related-card" href="${pageUrl(lang, key)}">${escapeHtml(c.related[key])}<span aria-hidden="true">↗</span></a>`,
  ).join('\n          ');

  return `<!doctype html>
<html lang="${locale.htmlLang}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#f2f0e8">
  <meta name="robots" content="index,follow">
  <title>${escapeHtml(p.title)}</title>
  <meta name="description" content="${escapeHtml(p.description)}">
  <link rel="canonical" href="${url}">
  ${alternateLinks(page)}
  <link rel="icon" href="/favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="/seo/site.css">
  <meta property="og:type" content="website">
  <meta property="og:site_name" content="Evil Space">
  <meta property="og:locale" content="${locale.ogLocale}">
  <meta property="og:title" content="${escapeHtml(p.title)}">
  <meta property="og:description" content="${escapeHtml(p.description)}">
  <meta property="og:url" content="${url}">
  <meta property="og:image" content="${business.origin}/seo/share.png">
  <meta property="og:image:alt" content="Evil Space Coworking, Nha Trang">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta name="twitter:card" content="summary_large_image">
  <script type="application/ld+json">${schema(lang, page)}</script>
</head>
<body>
  <a class="skip" href="#content">${escapeHtml(c.explore)}</a>
  <header class="masthead">
    <div class="masthead-inner wrap">
      <a class="brand" href="${pageUrl(lang, 'home')}" aria-label="Evil Space — ${escapeHtml(c.home)}"><img src="/favicon.svg" alt="" width="38" height="31"><span><strong>evil space</strong><span class="brand-small">COWORKING · NHA TRANG</span></span></a>
      <nav aria-label="${escapeHtml(c.navigation)}">
        ${nav}
        <a href="${bookingUrl}">${escapeHtml(c.book)} ↗</a>
      </nav>
    </div>
  </header>
  <div class="wrap language-row"><span>${escapeHtml(c.issue)}</span><div class="languages" aria-label="${escapeHtml(c.language)}">${langNav}</div></div>
  <main id="content">
    <div class="wrap">
      ${breadcrumbs}
      <section class="hero" aria-labelledby="page-heading">
        <div class="eyebrow">${escapeHtml(p.eyebrow)}</div>
        <h1 id="page-heading">${escapeHtml(p.heading)}</h1>
        <p class="lead">${escapeHtml(p.lead)}</p>
        <div class="hero-actions">${primaryAction}${mapAction}</div>
      </section>
      <div class="facts" aria-label="${escapeHtml(c.business)}">
        <div class="fact"><span class="fact-label">${escapeHtml(c.day)}</span><span class="fact-value">200K VND</span></div>
        <div class="fact"><span class="fact-label">${escapeHtml(c.month)}</span><span class="fact-value">2.5M VND</span></div>
        <div class="fact"><span class="fact-label">${escapeHtml(c.hours)}</span><span class="fact-value">11:00–23:00</span></div>
      </div>
      <section class="content" aria-labelledby="story-heading">
        <h2 class="section-title" id="story-heading"><span class="section-index">01 /</span>${escapeHtml(c.explore)}</h2>${story}
        <p class="note">${escapeHtml(c.bookingNote)}</p>
      </section>
      <section class="questions" aria-labelledby="questions-heading">
        <h2 class="section-title" id="questions-heading"><span class="section-index">02 /</span>${escapeHtml(c.questions)}</h2>
        <div class="qa-grid">${faqs}</div>
      </section>
      <section class="related" aria-labelledby="related-heading">
        <h2 class="section-title" id="related-heading"><span class="section-index">03 /</span>${escapeHtml(c.next)}</h2>
        <div class="related-grid">${related}</div>
      </section>
    </div>
    <section class="visit-strip" aria-labelledby="action-heading">
      <div class="wrap visit-inner"><div><div class="eyebrow">EVIL SPACE / NHA TRANG</div><h2 id="action-heading">${escapeHtml(p.ctaHeading)}</h2><p>${escapeHtml(p.ctaText)}</p></div><div class="visit-actions">${primaryAction}${mapAction}</div></div>
    </section>
  </main>
  <footer class="wrap footer">
    <div class="footer-grid">
      <div><strong>${escapeHtml(c.business)}</strong><p>${escapeHtml(c.footer)}</p></div>
      <div><p>${escapeHtml(c.address)}</p><p>${escapeHtml(c.open)} · 11:00–23:00</p><a href="tel:${business.phone}">${escapeHtml(c.phone)}</a></div>
      <div><a href="${escapeHtml(business.maps)}">${escapeHtml(c.photos)}</a><a href="${escapeHtml(business.instagram)}">Instagram</a><a href="${pageUrl(lang, 'pricing')}">${escapeHtml(c.prices)}</a></div>
    </div>
    <div class="footer-meta">© ${new Date().getUTCFullYear()} Evil Space · 60 Cao Văn Bé · Nha Trang</div>
  </footer>
</body>
</html>\n`;
}

function sitemap() {
  const urls = Object.keys(languages).flatMap((lang) => Object.keys(slugs).map((page) => ({ lang, page })));
  return `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n` +
    `  <url>\n    <loc>${business.origin}/</loc>\n  </url>\n` +
    urls.map(({ lang, page }) => `  <url>\n    <loc>${pageUrl(lang, page)}</loc>\n` +
      Object.keys(languages).map((other) => `    <xhtml:link rel="alternate" hreflang="${other}" href="${pageUrl(other, page)}"/>`).join('\n') +
      `\n    <xhtml:link rel="alternate" hreflang="x-default" href="${pageUrl('en', page)}"/>\n  </url>`).join('\n') +
    `\n</urlset>\n`;
}

export async function buildSeo(outputDir = path.join(root, 'build', 'web')) {
  const pricingSource = await readFile(path.join(root, 'worker', 'pricing.js'), 'utf8');
  for (const [name, value] of [
    ['DEFAULT_DAY_PASS_VND', business.dayVnd],
    ['DEFAULT_MONTH_PASS_VND', business.monthVnd],
  ]) {
    if (!pricingSource.includes(`export const ${name} = ${value};`)) {
      throw new Error(`SEO price mismatch: ${name}. Confirm current prices before release.`);
    }
  }
  for (const lang of Object.keys(languages)) {
    for (const [page, slug] of Object.entries(slugs)) {
      const folder = path.join(outputDir, lang, slug);
      await mkdir(folder, { recursive: true });
      await writeFile(path.join(folder, 'index.html'), renderPage(lang, page), 'utf8');
    }
  }
  await mkdir(path.join(outputDir, 'seo'), { recursive: true });
  await copyFile(path.join(root, 'seo', 'site.css'), path.join(outputDir, 'seo', 'site.css'));
  await copyFile(path.join(root, 'seo', 'share.png'), path.join(outputDir, 'seo', 'share.png'));
  await writeFile(path.join(outputDir, 'robots.txt'),
    `User-agent: *\nAllow: /\n\nSitemap: ${business.origin}/sitemap.xml\n`, 'utf8');
  await writeFile(path.join(outputDir, 'sitemap.xml'), sitemap(), 'utf8');
  console.log(`SEO: built ${Object.keys(languages).length * Object.keys(slugs).length} localized pages, robots.txt and sitemap.xml`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await buildSeo(process.argv[2] ? path.resolve(process.argv[2]) : undefined);
}
