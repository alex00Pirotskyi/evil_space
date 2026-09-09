PRAGMA foreign_keys = ON;

CREATE INDEX IF NOT EXISTS idx_memberships_customer_expires
  ON memberships(customer_id, expires_at);

CREATE INDEX IF NOT EXISTS idx_visits_membership_created
  ON visits(membership_id, created_at);

CREATE INDEX IF NOT EXISTS idx_visits_customer_created
  ON visits(customer_id, created_at);

CREATE INDEX IF NOT EXISTS idx_booking_requests_customer_id
  ON booking_requests(customer_id);

CREATE INDEX IF NOT EXISTS idx_purchase_requests_status_bought
  ON purchase_requests(status, bought_at DESC);

CREATE INDEX IF NOT EXISTS idx_customers_lower_name
  ON customers(lower(name));

CREATE INDEX IF NOT EXISTS idx_customers_lower_phone
  ON customers(lower(phone));

CREATE INDEX IF NOT EXISTS idx_customers_lower_telegram
  ON customers(lower(telegram));
