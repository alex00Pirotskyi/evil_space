CREATE TABLE IF NOT EXISTS pricing_settings (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  day_pass_vnd INTEGER NOT NULL CHECK (day_pass_vnd > 0),
  month_pass_vnd INTEGER NOT NULL CHECK (month_pass_vnd > 0),
  locker_month_vnd INTEGER NOT NULL CHECK (locker_month_vnd > 0),
  updated_at INTEGER NOT NULL DEFAULT 0,
  updated_by_email TEXT
);

INSERT OR IGNORE INTO pricing_settings
  (id, day_pass_vnd, month_pass_vnd, locker_month_vnd, updated_at)
VALUES (1, 200000, 2500000, 1000000, 0);

CREATE TABLE IF NOT EXISTS promotions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  description TEXT NOT NULL,
  start_day INTEGER NOT NULL,
  end_day INTEGER NOT NULL,
  start_minute INTEGER,
  end_minute INTEGER,
  day_pass_vnd INTEGER,
  month_pass_vnd INTEGER,
  locker_month_vnd INTEGER,
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0, 1)),
  created_at INTEGER NOT NULL,
  created_by_email TEXT NOT NULL,
  CHECK (end_day >= start_day),
  CHECK ((start_minute IS NULL AND end_minute IS NULL) OR
         (start_minute >= 0 AND start_minute < end_minute AND end_minute <= 1440)),
  CHECK (day_pass_vnd IS NULL OR day_pass_vnd > 0),
  CHECK (month_pass_vnd IS NULL OR month_pass_vnd > 0),
  CHECK (locker_month_vnd IS NULL OR locker_month_vnd > 0),
  CHECK (day_pass_vnd IS NOT NULL OR month_pass_vnd IS NOT NULL OR locker_month_vnd IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_promotions_active_window
ON promotions(enabled, start_day, end_day, id DESC);
