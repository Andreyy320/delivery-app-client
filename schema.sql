-- Схема восстановлена по запросам из delivery_backend/index.js
-- Запуск: psql -U postgres -d delivery -f schema.sql

CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  email         TEXT UNIQUE,
  phone         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'client',   -- client / business / courier / admin
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shops (
  id            SERIAL PRIMARY KEY,
  name          TEXT NOT NULL,
  category      TEXT NOT NULL,                    -- restaurant, product, apteka, svetok, ...
  login         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  phone         TEXT,
  address       TEXT,
  logo_url      TEXT,
  lat           BIGINT,                           -- в коде: градусы * 1 000 000
  lng           BIGINT,
  time          TEXT,                             -- график работы, например '09:00 - 22:00'
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  is_online     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id           SERIAL PRIMARY KEY,
  shop_id      INTEGER NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  category     TEXT,
  description  TEXT,
  image_url    TEXT,
  price        NUMERIC(10,2) NOT NULL DEFAULT 0,
  weight       TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  sizes        JSONB NOT NULL DEFAULT '[]',
  modifiers    JSONB NOT NULL DEFAULT '[]'
);
CREATE INDEX IF NOT EXISTS idx_products_shop ON products(shop_id);

CREATE TABLE IF NOT EXISTS orders (
  id                 SERIAL PRIMARY KEY,
  user_id            INTEGER REFERENCES users(id),
  shop_id            INTEGER REFERENCES shops(id),
  type               TEXT,
  category           TEXT,
  status             TEXT NOT NULL DEFAULT 'new', -- new/accepted/preparing/ready/delivery/delivered/cancelled
  client_name        TEXT,
  client_phone       TEXT,
  client_address     TEXT,
  client_lat         DOUBLE PRECISION,
  client_lng         DOUBLE PRECISION,
  restaurant_name    TEXT,
  restaurant_image   TEXT,
  restaurant_address TEXT,
  restaurant_lat     DOUBLE PRECISION,
  restaurant_lng     DOUBLE PRECISION,
  restaurant_comment TEXT,
  delivery_lat       DOUBLE PRECISION,
  delivery_lng       DOUBLE PRECISION,
  delivery_price     NUMERIC(10,2),
  distance_km        NUMERIC(8,2),
  duration_min       INTEGER,
  items_price        NUMERIC(10,2),
  total_price        NUMERIC(10,2),
  payment_method     TEXT,
  comment            TEXT,
  replacements       JSONB,
  items              JSONB NOT NULL DEFAULT '[]',
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_shop ON orders(shop_id);

CREATE TABLE IF NOT EXISTS delivery_orders (
  id         SERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS individual_deliveries (
  id                 SERIAL PRIMARY KEY,
  user_id            INTEGER REFERENCES users(id),
  client_id          TEXT,
  client_name        TEXT,
  client_phone       TEXT,
  name               TEXT,
  phone              TEXT,
  pickup_address     TEXT,
  pickup_address_id  INTEGER,
  dropoff_address    TEXT,
  dropoff_address_id INTEGER,
  distance_km        NUMERIC(8,2),
  duration_min       INTEGER,
  total_cost         NUMERIC(10,2),
  description        TEXT,
  type               TEXT,
  sub_type           TEXT,
  status             TEXT,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_indiv_user ON individual_deliveries(user_id);
