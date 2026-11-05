# Evil Space search operations

## Publish and verify

1. The minimalist Flutter booking app remains canonical and indexable at
   `https://evils.space/`. Three **real HTML, mobile-friendly, indexable**
   coworking information guides now supplement it:
   - `/en/coworking-nha-trang/`
   - `/ru/kovorking-nyachang/`
   - `/vi/khong-gian-lam-viec-nha-trang/`
   Each guide has a unique title, meta description, native visible text,
   self-canonical, reciprocal `hreflang` tags, genuine Google Maps
   photos/reviews and directions links, and a booking action to the homepage.
   The root links to each guide in native HTML and in its Flutter footer.
   The old `/en/`, `/ru/`, `/vi/`, pricing and visit URLs remain 301
   redirects to the homepage. `/admin`, `/menu` and `/qr` remain functional
   but `noindex`. Unknown paths return proper 404.
2. The localized copy and path manifest live in `seo/pages.mjs` and styles
   in `seo/site.css`. `tool/build_seo.mjs` generates the three pages,
   `robots.txt`, `sitemap.xml` and share image during each production build.
   `worker/seo_pages.js` serves language routes through Cloudflare static
   assets. Every language page appears in the sitemap, together with the root,
   with reciprocal EN/RU/VI and `x-default` annotations.
3. The production workflow deploys SEO-content and HTML changes on `main`.
   Other Flutter-only updates still follow the manual release process.
   Before deployment, `node --test test/seo_site_test.mjs`, the Worker
   integration suite, Flutter tests and `tool/verify_release.dart` validate
   HTML generation, routing, metadata and bundle size. After deployment,
   check HTTP 200 for four indexable URLs, HTTP 301 for old language roots,
   correct content type, self-canonicals, reciprocal `hreflang`, new sitemap,
   and HTTP 404 for invented URLs. Also test the Flutter app, menu, QR and admin.
4. Confirm factual business details before edits: owner-verified schedule is
   **Monday–Friday 10:00–23:00, weekends closed**, with address
   **60 Cao Văn Bé, Vĩnh Phước, Nha Trang**. The website's default regular
   day rate is **200K VND**, monthly rate **2.5M VND**; promotions/admin
   prices can vary. Do not list the studio, lecture room or other amenities
   as open without operational verification. Do not invent photos, review
   scores, customer testimonials, location coordinates or rankings.
5. Preserve the homepage's paper-style, compact booking UI. The service
   guides are genuinely useful standalone information, not duplicate
   Flutter app shells, hidden keyword blocks or fabricated doorway pages.
   Keep all language variations accurate and native. If business hours,
   rates or address change, update *both* `web/index.html` and
   `seo/pages.mjs`, plus the localized app copy and Business Profile.

## Google Search Console

The `evils.space` Domain property is verified. On September 26, 2026, URL
Inspection reported that the root is indexed, selected by Google as its own
canonical, and eligible for indexing in the live test. The sitemap is successful
and reports **one discovered page**. The Googlebot smartphone live test loaded
all resources and the rendered HTML contains Flutter's semantic app content;
its screenshot preview was blank, so recheck rendered content if a later crawl
loses it. Search Console's Web performance showed **31 impressions, 1 click**
and **3 impressions** for `coworking nha trang` with only September 23–24 data.
This is too small a sample to infer a reliable generic-query rank.
Indexing requests do not guarantee ranking, and repeating them does not speed
up the queue.

1. After release, submit/resubmit `https://evils.space/sitemap.xml` in Search
   Console, then inspect all four canonical URLs (root + three guides).
   Check status 200, declared vs Google-selected canonical, indexability and
   rendered text. Crawl/indexing is not instant and ranking is not guaranteed;
   do not repeatedly request indexing for unchanged pages.
2. In **Performance → Search results**, select **Web**, compare consistent
   country, date and device filters, and track impressions, clicks, CTR and
   average position for `coworking space nha trang`, `coworking nha trang`,
   `коворкинг нячанг`, Vietnamese coworking searches and the brand name.
   Sparse query data can be hidden by Google's privacy thresholds.
3. Distinguish website Search Console data from Google Business Profile search
   terms. Profile search counts show when a profile appeared on Search or Maps;
   they are not the website's organic rankings or clicks.

## Google Business Profile

1. Check the current **60 Cao Văn Bé, Vĩnh Phước, Nha Trang** address and map
   pin, phone **0565 056 748**, Monday–Friday **10:00–23:00** hours (closed Saturday–Sunday), Website link to
   `https://evils.space/` and primary category **Coworking space** against the
   actual business. A `53/14 Cao Văn Bé` search query does not prove that
   address belongs to this business; correct outdated external citations only
   after confirming the real address.
2. Add authentic current exterior, entrance and desk photos, accurate services
   and holiday hours. Request honest reviews from actual guests after visits
   and respond to them. Avoid keywords in the business name, invented
   amenities and purchased reviews.
3. Review **Website clicks**, **Calls** and **Directions** separately from
   organic website impressions and clicks. The April–September 2026 baseline
   supplied by the owner was **1,982 profile views** and **595 interactions**.
4. On September 26, 2026, the profile description was updated with the real
   coworking offer and short English, Russian and Vietnamese wording. The Instagram profile was added. On November 5, 2026 the owner clarified
   that Google Maps' Monday–Friday 10:00–23:00, weekend-closed schedule is correct;
   this supersedes the September hours note. The day-pass and monthly-desk services were
   submitted and were pending Google review. Check the published services and
   verify holiday hours and any future schedule changes against the operation.

## Google Maps / local rankings

Website changes **do not directly edit** Google Business Profile. Keep its
primary category accurate, local schedule, exterior/entrance photos, service
list, accessible phone and main website link to `https://evils.space/`
consistent with the actual business. Ask real customers for honest reviews
without incentives or review gating. The Google Maps photo/review links on
the SEO pages lead to the existing profile; new original images still require
real photographs from the venue.

## Editorial growth

Track *non-branded* EN/RU/VI query impressions, clicks and indexing by page;
use actual Search Console and Google Business Profile Performance exports
rather than guessed rankings. Evaluate which page attracts qualified visitors
and bookings before adding more pages. Keep the native language guides
well-maintained, address customer questions, and earn relevant citations
from real Nha Trang partners rather than buying links or reviews.
