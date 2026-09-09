PRAGMA foreign_keys = ON;

ALTER TABLE customers ADD COLUMN email TEXT;
ALTER TABLE customers ADD COLUMN telegram TEXT;
ALTER TABLE customers ADD COLUMN contact_other TEXT;
ALTER TABLE customers ADD COLUMN notes TEXT;
ALTER TABLE customers ADD COLUMN updated_at INTEGER;

ALTER TABLE memberships ADD COLUMN customer_id INTEGER;
ALTER TABLE visits ADD COLUMN customer_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_memberships_customer_id
  ON memberships(customer_id);

CREATE INDEX IF NOT EXISTS idx_visits_customer_id
  ON visits(customer_id);

CREATE TABLE IF NOT EXISTS booking_requests (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  contact_type TEXT NOT NULL
    CHECK (contact_type IN ('phone', 'telegram')),
  contact_value TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'new'
    CHECK (status IN ('new', 'accepted')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  handled_at INTEGER,
  handled_by_email TEXT,
  customer_id INTEGER
);

CREATE INDEX IF NOT EXISTS idx_booking_requests_status_created
  ON booking_requests(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_booking_requests_contact
  ON booking_requests(contact_type, contact_value);

INSERT INTO customers (name, created_at, updated_at)
SELECT source.name, MIN(source.created_at), unixepoch()
FROM (
  SELECT name, created_at FROM visits
  UNION ALL
  SELECT name, created_at FROM memberships
) AS source
WHERE NOT EXISTS (
  SELECT 1 FROM customers c WHERE lower(c.name) = lower(source.name)
)
GROUP BY lower(source.name);

UPDATE memberships
SET customer_id = (
  SELECT c.id
  FROM customers c
  WHERE lower(c.name) = lower(memberships.name)
  ORDER BY c.id
  LIMIT 1
)
WHERE customer_id IS NULL;

UPDATE visits
SET customer_id = (
  SELECT c.id
  FROM customers c
  WHERE lower(c.name) = lower(visits.name)
  ORDER BY c.id
  LIMIT 1
)
WHERE customer_id IS NULL;

UPDATE site_state
SET total_desks = 10,
    occupied_desks = 0,
    updated_at = unixepoch()
WHERE id = 1;
