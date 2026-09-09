ALTER TABLE booking_requests ADD COLUMN service_day INTEGER;
ALTER TABLE booking_requests ADD COLUMN amount_vnd INTEGER;

UPDATE booking_requests
SET service_day = CAST((created_at + 25200) / 86400 AS INTEGER) * 86400 - 25200
WHERE service_day IS NULL;

UPDATE booking_requests
SET amount_vnd = 200000
WHERE amount_vnd IS NULL;

CREATE INDEX IF NOT EXISTS idx_booking_requests_service_day_status
  ON booking_requests(service_day, status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_booking_requests_customer_service_day
  ON booking_requests(customer_id, service_day, status);
