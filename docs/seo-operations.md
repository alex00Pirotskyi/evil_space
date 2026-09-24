# Evil Space search operations

## Publish and check

1. Use `make build` or `make` with the pinned Flutter and Wrangler versions.
   The SEO generator runs after Flutter's web build. Do not upload only the
   Flutter build without the generated pages.
2. Check `/en/`, `/ru/`, `/vi/`, their `/pricing/` and `/visit/` pages,
   `/robots.txt` and `/sitemap.xml` on the live `https://evils.space` domain.
   Each page should return 200, contain readable localized HTML in View Source,
   and link to the booking app in its language. An unknown path such as
   `/en/does-not-exist` should return 404.
3. Inspect the live booking price before each release. The source business
   facts are in `seo/content.mjs`; the regular day price is **200K VND** and
   the month price is **2.5M VND**. Active offers or admin pricing changes can
   override the regular price. Keep visible copy, structured data and the
   Google Business Profile in sync.

## Google Search Console

The `evils.space` Domain property is verified. On **September 24, 2026**, the
submitted `https://evils.space/sitemap.xml` showed **Success** and **9 discovered
pages**. Discovery does not tell us whether any particular page is indexed.

1. After each production release, inspect `https://evils.space/en/`, `/ru/`
   and `/vi/` in the property's URL Inspection tool. Check **Indexing status**
   and **Google-selected canonical**, run **Test live URL** if necessary, and
   request indexing for important live pages that are eligible but not indexed.
   Check the Page indexing report for any crawl, canonical or soft-404 issues.
2. Review the Search results Performance report weekly with **Search type: Web**.
   Compare the same countries, devices and date ranges before and after changes.
   Track clicks, impressions, CTR and average position for
   `coworking nha trang`, `coworking space nha trang`,
   `коворкинг нячанг`, `không gian làm việc chung nha trang` and branded
   queries. Filter by page to learn whether Google chooses `/en/`, `/ru/`, `/vi/`
   or the Flutter booking app at `/` for each query.
3. Check Google-selected canonicals and the intended language alternates.
   Wait for meaningful search data before evaluating changes; a sitemap is a
   discovery signal, not a guarantee of indexing or placement.

## Google Business Profile

1. Check the listing's current **60 Cao Văn Bé, Vĩnh Phước, Nha Trang** address,
   map pin, phone **0565 056 748**, daily **11:00–23:00** hours and primary
   category **Coworking space** against the actual business. Older search terms
   include `53/14 Cao Văn Bé`; correct any stale third-party citations if the
   current listing is accurate. Do not change the listing address to match an
   old query.
2. Check the current **Website** link. If it points to `/` and qualified visitors
   leave before booking, try the most suitable public landing page (`/en/` or
   `/vi/`, based on the primary audience); both link to the Flutter booking app
   in one click. Compare Website clicks and bookings before keeping the change.
3. Add genuine current interior, exterior, entrance and desk photos, accurate
   services and price details, and holiday hours. Reply to real reviews.
   Avoid invented amenities, keywords in the business name and purchased
   reviews.
4. Inspect the profile's **Website clicks**, **Calls** and **Directions**
   separately from website impressions and clicks in Search Console. The
   April–September 2026 profile baseline supplied by the owner was **1,982
   views** and **595 interactions**; these are not organic website clicks.

## Editorial growth

Keep the three languages useful to their readers. Add only verifiable details:
original workspace and entrance photos with descriptive alt text, what a day
pass includes, payment options, Wi-Fi details, arrival guidance and any
confirmed special schedule. A page about a distinct
service should exist only if that service is currently available. Seek relevant
mentions from local Nha Trang directories, remote-work communities, hotels
and partner sites where the address and contact information can stay current.
Request honest reviews from real visitors after their visit; do not offer rewards
or buy links/reviews. The owner has to provide rights-cleared photos and confirm
the actual amenities before they can be accurately published here.
