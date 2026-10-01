-- Link a reservation to its booking so acceptance and capacity allocation can
-- commit together. Existing reservations keep their accepted_visit_id links.
ALTER TABLE visits ADD COLUMN booking_request_id INTEGER;
CREATE UNIQUE INDEX idx_visits_booking_request ON visits(booking_request_id);
