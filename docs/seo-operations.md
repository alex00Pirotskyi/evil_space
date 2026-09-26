# Evil Space search operations

## Publish and verify

1. `https://evils.space/` is the only public indexable page. Keep the Flutter
   web app and its PWA installation at this URL. The old `/en/`, `/ru/` and
   `/vi/` landing pages redirect to `/`; internal `/menu`, `/qr` and `/admin`
   routes work but are not indexable. Do not create localized public URLs to
   chase keywords without an explicit design change.
2. The GitHub production release runs automatically when `web/index.html` or
   another path listed in `.github/workflows/release.yml` changes on `main`.
   Flutter-only changes require the manual Production release workflow or
   `make`. Builds run checks, compile Flutter and deploy the Worker together.
3. After release, check the root URL, its visible rendered text, canonical,
   `/robots.txt`, `/sitemap.xml` and app installation. Verify that retired
   language URLs redirect to `/` and that unknown paths return 404. The
   sitemap must list the root only.
4. Verify all business facts against the operation before changing copy. The
   current regular day price is **200K VND** and monthly price **2.5M VND**;
   promotions or admin pricing may change what the app shows on a given day.
   Keep the business metadata in `web/index.html`, visible functional labels
   in `lib/localization.dart`, pricing in `worker/pricing.js`, and the Business
   Profile consistent. The owner wants a quiet booking tool: use the compact
   brand, location, hours, prices and actions already on the page. Owner-verified
   amenities belong in a small icon strip with brief labels and accessible
   descriptions. Do not add explanatory SEO paragraphs or hidden keyword text
   to the Flutter UI.

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

1. After significant releases, inspect `https://evils.space/` in URL
   Inspection. Check the last crawl, indexed canonical and live-rendered page.
   If a new version has not yet been crawled, wait for normal recrawling; do not
   keep resubmitting the same URL.
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
   pin, phone **0565 056 748**, daily **11:00–23:00** hours, Website link to
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
   coworking offer and short English, Russian and Vietnamese wording. Weekend
   hours were corrected from closed to 11:00–23:00 to match the published site;
   the Instagram profile was added. The day-pass and monthly-desk services were
   submitted and were pending Google review. Check the published services and
   verify holiday hours and any future schedule changes against the operation.

## Editorial growth

Keep the single page useful in each language through accurate prices, booking
availability, directions, and concise labels. Earn relevant mentions from
Nha Trang hotels, remote-work communities, local directories and partners with
accurate name, address and website; do not buy links or reviews. Google
recommends distinct URLs for full language-specific search targeting, so the
one-page design trades some Russian/Vietnamese search reach for its simple
visitor experience.
