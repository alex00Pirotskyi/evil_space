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

1. Verify a **Domain property** for `evils.space` using Google's DNS TXT
   record in the Cloudflare DNS zone. Keep any existing TXT records intact.
2. Submit `https://evils.space/sitemap.xml` in the property. Inspect `/en/`,
   `/ru/` and `/vi/` and request indexing after the production pages are live.
3. Review Page indexing and query performance weekly. Track clicks and
   impressions for `coworking nha trang`, `coworking space nha trang`,
   `коворкинг нячанг`, `không gian làm việc chung nha trang` and branded
   queries. Record a baseline before judging improvement.
4. Check Google-selected canonical and language alternates for each page.
   Crawl and ranking changes can take time; a sitemap is a discovery signal,
   not a guarantee of placement.

## Google Business Profile

1. Check the listing's current **60 Cao Văn Bé, Vĩnh Phước, Nha Trang** address,
   map pin, phone **0565 056 748**, daily **11:00–23:00** hours and primary
   category **Coworking space** against the actual business. Older search terms
   include `53/14 Cao Văn Bé`; correct any stale third-party citations if the
   current listing is accurate. Do not change the listing address to match an
   old query.
2. Add the website URL of the most suitable public landing page (`/en/` or
   `/vi/`, based on the primary audience) if the existing root booking URL is
   underperforming. Verify customers can still reach booking in one click.
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
workspace photos, what a day pass includes, payment options, Wi-Fi details,
arrival guidance and any confirmed special schedule. A page about a distinct
service should exist only if that service is currently available. Seek relevant
mentions from local Nha Trang directories, community sites and partner spaces
where the address and contact information can stay current.
