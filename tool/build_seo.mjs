import { copyFile, mkdir, rm, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const origin = 'https://evils.space';

// The Flutter app at / is the only indexable page. The old localized pages
// are retired and permanently redirected by worker/seo_pages.js.
export async function buildSeo(outputDir = path.join(root, 'build', 'web')) {
  await mkdir(outputDir, { recursive: true });
  for (const lang of ['en', 'ru', 'vi']) {
    await rm(path.join(outputDir, lang), { recursive: true, force: true });
  }
  await mkdir(path.join(outputDir, 'seo'), { recursive: true });
  await rm(path.join(outputDir, 'seo', 'site.css'), { force: true });
  await copyFile(path.join(root, 'seo', 'share.png'), path.join(outputDir, 'seo', 'share.png'));
  await writeFile(path.join(outputDir, 'robots.txt'),
    `User-agent: *\nAllow: /\n\nSitemap: ${origin}/sitemap.xml\n`, 'utf8');
  await writeFile(path.join(outputDir, 'sitemap.xml'),
    `<?xml version="1.0" encoding="UTF-8"?>\n` +
    `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n` +
    `  <url><loc>${origin}/</loc></url>\n</urlset>\n`, 'utf8');
  console.log('SEO: built root-only sitemap, robots.txt and share image');
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await buildSeo(process.argv[2] ? path.resolve(process.argv[2]) : undefined);
}
