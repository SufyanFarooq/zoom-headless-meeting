-- Cost settings per currency (admin configurable)
CREATE TABLE IF NOT EXISTS cost_settings (
  currency VARCHAR(10) PRIMARY KEY,
  normal_cost_per_bot DECIMAL(10,2) NOT NULL DEFAULT 0,
  profile_cost_per_bot DECIMAL(10,2) NOT NULL DEFAULT 0,
  webinar_cost_per_bot DECIMAL(10,2) NOT NULL DEFAULT 0,
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Seed default currencies with 0 cost
INSERT INTO cost_settings (currency, normal_cost_per_bot, profile_cost_per_bot, webinar_cost_per_bot)
VALUES 
  ('INR', 0, 0, 0),
  ('USD', 0, 0, 0),
  ('EUR', 0, 0, 0)
ON CONFLICT (currency) DO NOTHING;
