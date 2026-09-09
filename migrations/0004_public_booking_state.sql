ALTER TABLE booking_requests ADD COLUMN client_token_hash TEXT;
ALTER TABLE booking_requests ADD COLUMN accepted_visit_id INTEGER;

CREATE INDEX IF NOT EXISTS idx_booking_requests_client_token_hash
  ON booking_requests(client_token_hash);

CREATE INDEX IF NOT EXISTS idx_booking_requests_accepted_visit_id
  ON booking_requests(accepted_visit_id);
