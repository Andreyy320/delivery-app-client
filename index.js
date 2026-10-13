const express = require('express');
const crypto = require('crypto');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

// ==========================================
// ПРОВЕРКА НАСТРОЕК (.env)
// ==========================================
if (!process.env.JWT_SECRET || !process.env.DB_PASSWORD) {
  console.error('❌ В файле .env нет JWT_SECRET или DB_PASSWORD. Сервер не запущен.');
  process.exit(1);
}
if (process.env.JWT_SECRET.length < 32 || process.env.JWT_SECRET.includes('СЮДА')) {
  console.error('❌ JWT_SECRET слишком короткий или это заглушка. Сгенерируйте: openssl rand -hex 48');
  process.exit(1);
}
if (!process.env.ADMIN_KEY || process.env.ADMIN_KEY.length < 24) {
  console.warn('⚠️  ADMIN_KEY не задан или короче 24 символов: админские роуты будут недоступны.');
}

const app = express();
app.disable('x-powered-by');

// За nginx укажите TRUST_PROXY=1, иначе все клиенты выглядят как один IP (ломаются лимиты)
if (process.env.TRUST_PROXY) {
  app.set('trust proxy', Number(process.env.TRUST_PROXY) || 1);
}

// Базовые защитные заголовки
app.use((req, res, next) => {
  res.set({
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'no-referrer',
    'Cache-Control': 'no-store',
  });
  next();
});

app.use(express.json({ limit: '100kb' }));

// CORS нужен только браузерам (веб-панель). Мобильному приложению он не нужен.
// Разрешённые адреса: CORS_ORIGINS=https://panel.example.com,https://admin.example.com
const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
if (corsOrigins.length) {
  app.use(cors({ origin: corsOrigins }));
}

// Подключение к PostgreSQL
const pool = new Pool({
  user: process.env.DB_USER || 'delivery_user',
  host: process.env.DB_HOST || 'localhost',
  database: process.env.DB_NAME || 'delivery',
  password: process.env.DB_PASSWORD,
  port: Number(process.env.DB_PORT) || 5432,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  statement_timeout: 10000, // долгий запрос не повесит сервер
});
pool.on('error', (err) => {
  console.error('Ошибка соединения с PostgreSQL:', err.message);
});

const JWT_SECRET = process.env.JWT_SECRET;
const JWT_TTL = process.env.JWT_TTL || '30d';

// ==========================================
// ПОМОЩНИКИ
// ==========================================

const MAX_INT = 2147483647; // предел integer в PostgreSQL
const MAX_MONEY = 10000000;

// Положительное целое (id). Иначе null.
function toId(value) {
  const s = String(value === undefined || value === null ? '' : value).trim();
  if (!/^\d{1,10}$/.test(s)) return null;
  const n = Number(s);
  return n > 0 && n <= MAX_INT ? n : null;
}

function isNum(value) {
  return (
    (typeof value === 'number' || typeof value === 'string') &&
    value !== '' &&
    Number.isFinite(Number(value))
  );
}

function isMoney(value) {
  return isNum(value) && Number(value) >= 0 && Number(value) <= MAX_MONEY;
}

function isLat(value) {
  return isNum(value) && Math.abs(Number(value)) <= 90;
}

function isLng(value) {
  return isNum(value) && Math.abs(Number(value)) <= 180;
}

function isNonEmptyString(value, maxLen = 200) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxLen;
}

// Строка или null; длинное обрезается
function strOrNull(value, max = 200) {
  if (typeof value !== 'string') return null;
  const t = value.trim();
  return t ? t.slice(0, max) : null;
}

function numOrNull(value) {
  return value === undefined || value === null || value === '' ? null : Number(value);
}

function isHttpUrl(value, max = 500) {
  if (typeof value !== 'string' || value.length > max) return false;
  try {
    const u = new URL(value);
    return u.protocol === 'https:' || u.protocol === 'http:'; // лучше оставить только https
  } catch {
    return false;
  }
}

function isPhone(value) {
  return typeof value === 'string' && /^\+?[\d\s\-()]{6,20}$/.test(value.trim());
}

function isEmail(value) {
  return typeof value === 'string' && value.length <= 254 && /^[^\s@]{1,64}@[^\s@]{1,255}$/.test(value.trim());
}

// bcrypt обрезает пароль на 72 байтах
function passwordProblem(password) {
  if (typeof password !== 'string' || password.length < 6) return 'Пароль слишком короткий (мин. 6 символов)';
  if (Buffer.byteLength(password, 'utf8') > 72) return 'Пароль слишком длинный (макс. 72 байта)';
  return null;
}

function randomPassword() {
  return crypto.randomBytes(9).toString('base64url');
}

// JSON-массив (sizes, modifiers): принимает массив или строку с массивом, возвращает строку
function normalizeJsonArray(value) {
  let arr = value;
  if (typeof value === 'string') {
    try {
      arr = JSON.parse(value);
    } catch {
      return null;
    }
  }
  if (!Array.isArray(arr) || arr.length > 100) return null;
  const s = JSON.stringify(arr);
  return s.length <= 20000 ? s : null;
}

// Фиктивный хэш: чтобы вход с несуществующим логином занимал столько же времени
const DUMMY_HASH = bcrypt.hashSync('dummy-password-for-timing', 10);

// ==========================================
// ОГРАНИЧЕНИЕ ЧАСТОТЫ ЗАПРОСОВ
// ==========================================
function createRateLimiter({ windowMs, max, keyFn, message }) {
  const hits = new Map();
  setInterval(() => {
    const now = Date.now();
    for (const [key, entry] of hits) {
      if (entry.resetAt <= now) hits.delete(key);
    }
  }, Math.min(windowMs, 60 * 1000)).unref();

  return (req, res, next) => {
    const key = keyFn ? keyFn(req) : req.ip;
    const now = Date.now();
    let entry = hits.get(key);
    if (!entry || entry.resetAt <= now) {
      if (hits.size > 200000) hits.clear(); // защита памяти от флуда уникальными ключами
      entry = { count: 0, resetAt: now + windowMs };
      hits.set(key, entry);
    }
    entry.count += 1;
    if (entry.count > max) {
      res.set('Retry-After', String(Math.ceil((entry.resetAt - now) / 1000)));
      return res.status(429).json({
        success: false,
        error: message || 'Слишком много попыток. Попробуйте позже',
      });
    }
    next();
  };
}

const bodyField = (req, name) =>
  String((req.body && req.body[name]) || '').trim().toLowerCase().slice(0, 100);

// Общий лимит на весь API с одного IP
const apiLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 600,
  message: 'Слишком много запросов. Попробуйте позже',
});
const loginLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyFn: (req) => `${req.ip}|${bodyField(req, 'phone')}`,
  message: 'Слишком много попыток входа. Попробуйте через 15 минут',
});
// Подбор пароля к одному номеру с разных IP
const loginPhoneLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 30,
  keyFn: (req) => `phone|${bodyField(req, 'phone')}`,
  message: 'Слишком много попыток входа. Попробуйте через 15 минут',
});
const shopLoginLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyFn: (req) => `${req.ip}|${bodyField(req, 'login')}`,
  message: 'Слишком много попыток входа. Попробуйте через 15 минут',
});
const shopLoginNameLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 30,
  keyFn: (req) => `login|${bodyField(req, 'login')}`,
  message: 'Слишком много попыток входа. Попробуйте через 15 минут',
});
const registerLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000,
  max: 20,
  message: 'Слишком много регистраций с этого адреса. Попробуйте позже',
});
const businessRequestLimiter = createRateLimiter({
  windowMs: 60 * 60 * 1000,
  max: 10,
  message: 'Слишком много заявок с этого адреса. Попробуйте позже',
});
const changePasswordLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10,
  keyFn: (req) =>
    `${req.ip}|${(req.user && req.user.id) || (req.shop && req.shop.id) || ''}`,
  message: 'Слишком много попыток смены пароля. Попробуйте позже',
});
const adminLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 60,
  message: 'Слишком много запросов к админке. Попробуйте позже',
});
const orderCreateLimiter = createRateLimiter({
  windowMs: 10 * 60 * 1000,
  max: 30,
  keyFn: (req) => `order|${req.ip}|${(req.user && req.user.id) || ''}`,
  message: 'Слишком много заказов за короткое время. Попробуйте позже',
});

app.use('/api', apiLimiter);

// ==========================================
// АВТОРИЗАЦИЯ (теперь всегда обязательна там, где нужна)
// ==========================================

// Роли, которые можно получить через открытую регистрацию (через запятую в .env)
const PUBLIC_ROLES = (process.env.PUBLIC_ROLES || 'client')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);

function readToken(req) {
  const header = req.headers['authorization'] || '';
  const [scheme, token] = header.split(' ');
  return scheme && scheme.toLowerCase() === 'bearer' && token ? token : null;
}

function authFail(req, res) {
  return res.status(401).json({
    success: false,
    error: req.authError ? 'Недействительный или просроченный токен' : 'Требуется авторизация',
  });
}

// Мягкий разбор токена: заполняет req.user / req.shop, если токен верный.
// Публичные роуты (список заведений, меню) работают даже с просроченным токеном.
function softAuth(req, res, next) {
  const token = readToken(req);
  if (!token) return next();

  jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }, (err, decoded) => {
    if (err || !decoded || typeof decoded !== 'object') {
      req.authError = true;
      return next();
    }
    const userId = toId(decoded.userId || decoded.id);
    const shopId = toId(decoded.shopId);
    if (userId) req.user = { id: userId };
    if (shopId) req.shop = { id: shopId };
    next();
  });
}
app.use(softAuth);

// Нужен вошедший клиент
function needUser(req, res, next) {
  if (!req.user) return authFail(req, res);
  next();
}
const verifyToken = needUser;

// Нужен вошедший магазин, и это именно его магазин (и он ещё активен)
async function needShop(req, res, next) {
  try {
    if (!req.shop) return authFail(req, res);
    if (req.params.shopId && String(req.shop.id) !== String(req.params.shopId)) {
      return res.status(403).json({ success: false, error: 'Это чужой магазин' });
    }
    const r = await pool.query('SELECT is_active FROM shops WHERE id = $1', [req.shop.id]);
    if (r.rows.length === 0 || r.rows[0].is_active !== true) {
      return res.status(403).json({ success: false, error: 'Магазин отключён' });
    }
    next();
  } catch (err) {
    next(err);
  }
}

// Подойдёт и клиент, и магазин
function needAny(req, res, next) {
  if (!req.user && !req.shop) return authFail(req, res);
  next();
}

const sha256 = (s) => crypto.createHash('sha256').update(String(s)).digest();

// Только админ (ключ ADMIN_KEY из .env, заголовок x-admin-key)
function needAdmin(req, res, next) {
  const expected = process.env.ADMIN_KEY || '';
  const given = req.headers['x-admin-key'] || '';
  const ok =
    expected.length >= 24 && crypto.timingSafeEqual(sha256(expected), sha256(given));
  if (!ok) {
    return res.status(403).json({ success: false, error: 'Только для администратора' });
  }
  next();
}

// Тестовый роут
app.get('/', (req, res) => {
  res.json({ message: 'Server is running' });
});

// ==========================================
// КЛИЕНТЫ: РЕГИСТРАЦИЯ, ВХОД, ПАРОЛЬ
// ==========================================

// --- 1. РЕГИСТРАЦИЯ ---
app.post('/api/register', registerLimiter, async (req, res) => {
  try {
    const { name, email, phone, password, role } = req.body || {};

    if (!password) {
      return res.status(400).json({ success: false, error: 'Введите пароль' });
    }
    const pwProblem = passwordProblem(password);
    if (pwProblem) {
      return res.status(400).json({ success: false, error: pwProblem });
    }
    if (!isNonEmptyString(phone, 30) || !isPhone(phone)) {
      return res.status(400).json({ success: false, error: 'Введите корректный номер телефона' });
    }
    if (!isNonEmptyString(name, 100)) {
      return res.status(400).json({ success: false, error: 'Введите имя' });
    }
    if (email !== undefined && email !== null && email !== '' && !isEmail(email)) {
      return res.status(400).json({ success: false, error: 'Некорректный email' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    // Через открытый роут нельзя получить привилегированную роль
    const safeRole = PUBLIC_ROLES.includes(role) ? role : 'client';
    const safeEmail = typeof email === 'string' && email.trim() ? email.trim() : null;

    const query = `
      INSERT INTO users (name, email, phone, password_hash, role)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, name, email, phone, role, created_at
    `;
    const values = [name.trim(), safeEmail, phone.trim(), passwordHash, safeRole];

    const result = await pool.query(query, values);
    const user = result.rows[0];

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_TTL });

    res.json({ success: true, token, user });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ success: false, error: 'Пользователь с таким телефоном или email уже существует' });
    }
    console.error('Ошибка регистрации:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при регистрации' });
  }
});

// --- 2. ВХОД (ЛОГИН) ---
app.post('/api/login', loginLimiter, loginPhoneLimiter, async (req, res) => {
  try {
    const { phone, password } = req.body || {};

    if (typeof phone !== 'string' || typeof password !== 'string' || !phone || !password) {
      return res.status(400).json({ success: false, error: 'Введите телефон и пароль' });
    }
    if (phone.length > 30 || password.length > 128) {
      return res.status(400).json({ success: false, error: 'Неверный телефон или пароль' });
    }

    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone.trim()]);
    const user = result.rows[0];

    // Одинаковый ответ и время для «нет такого пользователя» и «неверный пароль»
    const isMatch = await bcrypt.compare(password, user ? user.password_hash : DUMMY_HASH);
    if (!user || !isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный телефон или пароль' });
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: JWT_TTL });

    res.json({
      success: true,
      token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
      },
    });
  } catch (err) {
    console.error('Ошибка входа:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// --- Смена пароля клиента ---
app.post('/api/auth/change-password', verifyToken, changePasswordLimiter, async (req, res) => {
  try {
    const userId = req.user.id;
    const { oldPassword, newPassword } = req.body || {};

    if (typeof oldPassword !== 'string' || typeof newPassword !== 'string' || !oldPassword || !newPassword) {
      return res.status(400).json({ success: false, error: 'Заполните все поля' });
    }
    const pwProblem = passwordProblem(newPassword);
    if (pwProblem) {
      return res.status(400).json({ success: false, error: pwProblem });
    }
    if (oldPassword.length > 128) {
      return res.status(400).json({ success: false, error: 'Неверный старый пароль' });
    }

    const userResult = await pool.query('SELECT password_hash FROM users WHERE id = $1', [userId]);
    if (userResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Пользователь не найден' });
    }

    const isMatch = await bcrypt.compare(oldPassword, userResult.rows[0].password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный старый пароль' });
    }

    const newPasswordHash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [newPasswordHash, userId]);

    res.json({ success: true, message: 'Пароль успешно изменён' });
  } catch (err) {
    console.error('Ошибка при смене пароля:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// ==========================================
// ЗАКАЗЫ КЛИЕНТОВ
// ==========================================

// Статусы, которые может ставить магазин (уберите лишнее, когда появится роль курьера)
const SHOP_STATUSES = [
  'accepted', 'preparing', 'ready', 'action_required',
  'delivery', 'inProgress', 'delivered', 'cancelled',
];
// Завершённые заказы менять нельзя
const TERMINAL_STATUSES = ['delivered', 'cancelled'];
// Что может сделать клиент: новый статус -> из каких текущих статусов можно перейти
const CLIENT_TRANSITIONS = {
  cancelled: ['new', 'action_required'],
  zamena: ['action_required'], // клиент принял замену
};
// Какие заказы клиент может удалить из истории
const DELETABLE_STATUSES = ['delivered', 'cancelled'];

// --- СОЗДАНИЕ ЗАКАЗА ---
app.post('/api/orders', needUser, orderCreateLimiter, async (req, res) => {
  try {
    const d = req.body || {};

    // Пользователь всегда из токена, user_id из тела игнорируется
    const orderUserId = req.user.id;

    // Заведение должно существовать и быть активным
    const shopId = toId(d.shop_id);
    if (shopId === null) {
      return res.status(400).json({ success: false, error: 'Не указано заведение' });
    }
    const shopResult = await pool.query(
      'SELECT is_active, name, logo_url FROM shops WHERE id = $1',
      [shopId]
    );
    if (shopResult.rows.length === 0 || shopResult.rows[0].is_active !== true) {
      return res.status(400).json({ success: false, error: 'Заведение недоступно' });
    }
    const shop = shopResult.rows[0];

    // Проверка чисел: если пришли, то должны быть корректными
    const checks = [
      [['delivery_price', 'items_price', 'total_price', 'distance_km', 'duration_min'], isMoney],
      [['client_lat', 'restaurant_lat', 'delivery_lat'], isLat],
      [['client_lng', 'restaurant_lng', 'delivery_lng'], isLng],
    ];
    for (const [fields, check] of checks) {
      for (const f of fields) {
        if (d[f] !== undefined && d[f] !== null && !check(d[f])) {
          return res.status(400).json({ success: false, error: `Некорректное значение поля ${f}` });
        }
      }
    }

    const query = `
      INSERT INTO orders (
        user_id,
        shop_id, type, category, status, client_name, client_phone,
        client_address, client_lat, client_lng, restaurant_name,
        restaurant_image, restaurant_address, restaurant_lat, restaurant_lng, restaurant_comment,
        delivery_lat, delivery_lng, delivery_price, distance_km, duration_min,
        items_price, total_price, payment_method, comment, replacements
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
        $21, $22, $23, $24, $25, $26
      ) RETURNING id;
    `;

    const values = [
      orderUserId,
      shopId,
      strOrNull(d.type, 50),
      strOrNull(d.category, 50),
      'new', // стартовый статус задаёт только сервер
      strOrNull(d.client_name, 100),
      strOrNull(d.client_phone, 30),
      strOrNull(d.client_address, 300),
      numOrNull(d.client_lat),
      numOrNull(d.client_lng),
      shop.name, // название и логотип берём из базы, а не из запроса
      shop.logo_url || '',
      strOrNull(d.restaurant_address, 300),
      numOrNull(d.restaurant_lat),
      numOrNull(d.restaurant_lng),
      strOrNull(d.restaurant_comment, 500),
      numOrNull(d.delivery_lat),
      numOrNull(d.delivery_lng),
      numOrNull(d.delivery_price),
      numOrNull(d.distance_km),
      numOrNull(d.duration_min),
      numOrNull(d.items_price),
      numOrNull(d.total_price),
      strOrNull(d.payment_method, 30),
      strOrNull(d.comment, 500),
      '[]', // замены создаёт только магазин
    ];

    const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      orderId: result.rows[0].id,
      message: 'Заказ успешно создан',
    });
  } catch (error) {
    console.error('Ошибка при создании заказа:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера при создании заказа' });
  }
});

// --- ИСТОРИЯ ЗАКАЗОВ КЛИЕНТА ---
app.get('/api/orders/user/:userId', needUser, async (req, res) => {
  try {
    let raw = String(req.params.userId);

    // Совместимость: старые версии приложения могли прислать объект строкой "{id: 5, ...}"
    const match = raw.match(/id:\s*(\d+)/);
    if (match) raw = match[1];

    const requestedUserId = toId(raw);
    if (requestedUserId === null) {
      return res.status(400).json({ success: false, error: 'Неверный формат ID пользователя' });
    }

    // Клиент видит только свои заказы
    if (Number(req.user.id) !== requestedUserId) {
      return res.status(403).json({ success: false, error: 'Нет доступа к чужим заказам' });
    }

    const result = await pool.query(
      'SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC LIMIT 200;',
      [requestedUserId]
    );

    res.status(200).json({ success: true, orders: result.rows });
  } catch (error) {
    console.error('Ошибка при получении истории заказов:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// --- УДАЛИТЬ ЗАКАЗ ИЗ ИСТОРИИ (только свой и только завершённый) ---
app.delete('/api/orders/:id', needUser, async (req, res) => {
  try {
    const id = toId(req.params.id);
    if (id === null) {
      return res.status(400).json({ success: false, error: 'Неверный ID заказа' });
    }

    const result = await pool.query(
      'DELETE FROM orders WHERE id = $1 AND user_id = $2 AND status::text = ANY($3::text[])',
      [id, req.user.id, DELETABLE_STATUSES]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({
        success: false,
        error: 'Заказ не найден или ещё не завершён (активные заказы удалять нельзя)',
      });
    }

    res.status(200).json({ success: true, message: 'Заказ успешно удален' });
  } catch (error) {
    console.error('Ошибка при удалении заказа:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// --- ОБНОВЛЕНИЕ ЗАКАЗА (замены, смена статуса) ---
app.patch('/api/orders/:orderId/update', needAny, async (req, res) => {
  try {
    const orderId = toId(req.params.orderId);
    if (orderId === null) {
      return res.status(400).json({ success: false, error: 'Неверный ID заказа' });
    }
    const body = req.body || {};

    const found = await pool.query('SELECT user_id, shop_id, status FROM orders WHERE id = $1', [orderId]);
    if (!found.rows.length) {
      return res.status(404).json({ success: false, error: 'Заказ не найден' });
    }
    const order = found.rows[0];
    const currentStatus = String(order.status);

    // Проверка владельца: магазин меняет только заказы своего магазина, клиент только свои
    const isShop = Boolean(req.shop);
    if (isShop) {
      if (String(order.shop_id) !== String(req.shop.id)) {
        return res.status(403).json({ success: false, error: 'Это заказ другого магазина' });
      }
    } else if (String(order.user_id) !== String(req.user.id)) {
      return res.status(403).json({ success: false, error: 'Это чужой заказ' });
    }

    const updates = {};

    if (body.status !== undefined) {
      if (!isNonEmptyString(body.status, 50)) {
        return res.status(400).json({ success: false, error: 'Некорректный статус' });
      }
      const next = body.status.trim();

      if (isShop) {
        if (!SHOP_STATUSES.includes(next)) {
          return res.status(403).json({ success: false, error: 'Магазин не может поставить такой статус' });
        }
        if (TERMINAL_STATUSES.includes(currentStatus)) {
          return res.status(409).json({ success: false, error: 'Заказ уже завершён' });
        }
      } else {
        const allowedFrom = CLIENT_TRANSITIONS[next];
        if (!allowedFrom || !allowedFrom.includes(currentStatus)) {
          return res.status(403).json({ success: false, error: 'Нельзя изменить статус заказа так' });
        }
      }
      updates.status = next;
    }

    if (body.replacements !== undefined) {
      if (!isShop) {
        return res.status(403).json({ success: false, error: 'Менять замены может только заведение' });
      }
      if (TERMINAL_STATUSES.includes(currentStatus)) {
        return res.status(409).json({ success: false, error: 'Заказ уже завершён' });
      }
      const json = JSON.stringify(body.replacements);
      if (!Array.isArray(body.replacements) || body.replacements.length > 50 || json.length > 20000) {
        return res.status(400).json({ success: false, error: 'Некорректные замены' });
      }
      updates.replacements = json;
    }

    const keys = Object.keys(updates); // имена колонок задаёт только сервер
    if (!keys.length) {
      return res.status(400).json({ success: false, error: 'Нет полей для обновления' });
    }

    const setClauses = keys.map((k, i) => `${k} = $${i + 1}`);
    const values = keys.map((k) => updates[k]);
    values.push(orderId);
    const idIdx = values.length;
    values.push(currentStatus);
    const statusIdx = values.length;

    // Условие по статусу защищает от гонки: если статус успели сменить, обновление не пройдёт
    const result = await pool.query(
      `UPDATE orders SET ${setClauses.join(', ')} WHERE id = $${idIdx} AND status::text = $${statusIdx} RETURNING *`,
      values
    );

    if (!result.rows.length) {
      return res.status(409).json({ success: false, error: 'Статус заказа уже изменился, обновите экран' });
    }

    res.json({ success: true, order: result.rows[0] });
  } catch (error) {
    console.error('Ошибка обновления заказа:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// ==========================================
// ИНДИВИДУАЛЬНЫЕ ДОСТАВКИ
// ==========================================

// Стартовый статус индивидуальной доставки задаёт сервер (должен совпадать с тем, что ждёт приложение)
const INDIVIDUAL_START_STATUS = process.env.INDIVIDUAL_START_STATUS || 'new';

app.post('/api/individual-orders', verifyToken, orderCreateLimiter, async (req, res) => {
  try {
    const b = req.body || {};

    for (const [field, value] of [
      ['distance_km', b.distance_km],
      ['duration_min', b.duration_min],
      ['total_cost', b.total_cost],
    ]) {
      if (value !== undefined && value !== null && !isMoney(value)) {
        return res.status(400).json({ success: false, error: `Некорректное значение поля ${field}` });
      }
    }

    const query = `
      INSERT INTO individual_deliveries (
        user_id, client_id, client_name, client_phone, name, phone,
        pickup_address, pickup_address_id, dropoff_address, dropoff_address_id,
        distance_km, duration_min, total_cost, description, type, sub_type, status, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW())
      RETURNING *;
    `;

    // user_id и client_id всегда из токена, статус всегда задаёт сервер
    const values = [
      req.user.id,
      req.user.id,
      strOrNull(b.client_name, 100),
      strOrNull(b.client_phone, 30),
      strOrNull(b.name, 100),
      strOrNull(b.phone, 30),
      strOrNull(b.pickup_address, 300),
      strOrNull(b.pickup_address_id !== undefined && b.pickup_address_id !== null ? String(b.pickup_address_id) : null, 100),
      strOrNull(b.dropoff_address, 300),
      strOrNull(b.dropoff_address_id !== undefined && b.dropoff_address_id !== null ? String(b.dropoff_address_id) : null, 100),
      numOrNull(b.distance_km),
      numOrNull(b.duration_min),
      numOrNull(b.total_cost),
      strOrNull(b.description, 1000),
      strOrNull(b.type, 50),
      strOrNull(b.sub_type, 50),
      INDIVIDUAL_START_STATUS,
    ];

    const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      message: 'Индивидуальная доставка успешно создана',
      order: result.rows[0],
    });
  } catch (error) {
    console.error('Error creating individual order:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера при создании доставки' });
  }
});

app.get('/api/individual-orders', verifyToken, async (req, res) => {
  try {
    // Только заказы текущего пользователя (из токена)
    const result = await pool.query(
      'SELECT * FROM individual_deliveries WHERE user_id = $1 ORDER BY created_at DESC LIMIT 200;',
      [req.user.id]
    );
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching individual orders:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// Удаление индивидуальной доставки (только своей)
async function deleteIndividualDelivery(req, res) {
  try {
    const id = toId(req.params.id);
    if (id === null) {
      return res.status(400).json({ success: false, error: 'Неверный ID доставки' });
    }

    const result = await pool.query(
      'DELETE FROM individual_deliveries WHERE id = $1 AND user_id = $2',
      [id, req.user.id]
    );
    if (result.rowCount === 0) {
      return res.status(404).json({ success: false, error: 'Доставка не найдена' });
    }

    res.status(200).json({ success: true, message: 'Доставка успешно удалена' });
  } catch (error) {
    console.error('Ошибка при удалении доставки:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
}
app.delete('/api/individual-orders/:id', needUser, deleteIndividualDelivery);
// Старое имя роута: приложение вызывает именно его
app.delete('/api/delivery-orders/:id', needUser, deleteIndividualDelivery);

// ==========================================
// ЗАВЕДЕНИЯ И МЕНЮ (ПУБЛИЧНЫЕ)
// ==========================================

// Список активных заведений
app.get('/api/shops', async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, name, category, logo_url, time, is_online FROM shops WHERE is_active = true'
    );

    res.json({
      success: true,
      shops: result.rows.map((shop) => ({
        id: shop.id,
        title: shop.name,
        category: shop.category,
        image_url: shop.logo_url,
        time: shop.time,
        is_online: shop.is_online,
      })),
    });
  } catch (err) {
    console.error('Ошибка при получении заведений:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// Меню заведения (только активного)
app.get('/api/shops/:shopId/menu', async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ success: false, error: 'Неверный ID заведения' });
    }

    const result = await pool.query(
      `SELECT p.id, p.title AS name, p.category, p.price, p.weight, p.description,
              p.image_url, p.is_available, p.sizes, p.modifiers
       FROM products p
       JOIN shops s ON s.id = p.shop_id
       WHERE p.shop_id = $1 AND s.is_active = true`,
      [shopId]
    );

    res.json({
      success: true,
      menu: result.rows.map((dish) => ({
        id: dish.id,
        name: dish.name,
        category: dish.category,
        price: dish.price,
        weight: dish.weight,
        description: dish.description,
        imagePath: dish.image_url,
        isAvailable: dish.is_available,
        size: dish.sizes,
        modifiers: dish.modifiers,
      })),
    });
  } catch (err) {
    console.error('Ошибка при получении меню:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// ==========================================
// МАГАЗИНЫ (ПАРТНЁРЫ): ВХОД, ТОВАРЫ, ЗАКАЗЫ
// ==========================================

// --- ВХОД ДЛЯ МАГАЗИНА (ПАРТНЕРА) ---
app.post('/api/shops/login', shopLoginLimiter, shopLoginNameLimiter, async (req, res) => {
  try {
    const { login, password } = req.body || {};

    if (typeof login !== 'string' || typeof password !== 'string' || !login || !password) {
      return res.status(400).json({ success: false, error: 'Введите логин и пароль' });
    }
    if (login.length > 254 || password.length > 128) {
      return res.status(400).json({ success: false, error: 'Неверный логин или пароль' });
    }

    const result = await pool.query('SELECT * FROM shops WHERE login = $1', [login.trim()]);
    const shop = result.rows[0];

    const isMatch = await bcrypt.compare(password, shop ? shop.password_hash : DUMMY_HASH);
    if (!shop || !isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный логин или пароль' });
    }
    if (shop.is_active !== true) {
      return res.status(403).json({ success: false, error: 'Заведение ещё не подтверждено или отключено' });
    }

    const token = jwt.sign({ shopId: shop.id }, JWT_SECRET, { expiresIn: JWT_TTL });

    res.json({
      success: true,
      token,
      shop: {
        id: shop.id,
        name: shop.name,
        login: shop.login,
        category: shop.category,
      },
    });
  } catch (err) {
    console.error('Ошибка входа магазина:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при входе магазина' });
  }
});

// --- Смена пароля магазина ---
app.post('/api/shops/change-password', needShop, changePasswordLimiter, async (req, res) => {
  try {
    const { oldPassword, newPassword } = req.body || {};
    if (typeof oldPassword !== 'string' || typeof newPassword !== 'string' || !oldPassword || !newPassword) {
      return res.status(400).json({ success: false, error: 'Заполните все поля' });
    }
    const pwProblem = passwordProblem(newPassword);
    if (pwProblem) {
      return res.status(400).json({ success: false, error: pwProblem });
    }
    if (oldPassword.length > 128) {
      return res.status(400).json({ success: false, error: 'Неверный старый пароль' });
    }

    const r = await pool.query('SELECT password_hash FROM shops WHERE id = $1', [req.shop.id]);
    if (!r.rows.length) {
      return res.status(404).json({ success: false, error: 'Магазин не найден' });
    }
    const isMatch = await bcrypt.compare(oldPassword, r.rows[0].password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный старый пароль' });
    }

    const hash = await bcrypt.hash(newPassword, 10);
    await pool.query('UPDATE shops SET password_hash = $1 WHERE id = $2', [hash, req.shop.id]);
    res.json({ success: true, message: 'Пароль успешно изменён' });
  } catch (err) {
    console.error('Ошибка смены пароля магазина:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// Проверка и приведение полей товара. Возвращает { error } или { data }.
function validateProductFields(f, { create }) {
  const data = {};

  if (create || f.title !== undefined) {
    if (!isNonEmptyString(f.title, 200)) return { error: 'Укажите название товара' };
    data.title = f.title.trim();
  }
  if (f.category !== undefined) {
    if (f.category !== null && (typeof f.category !== 'string' || f.category.length > 100)) {
      return { error: 'Некорректная категория' };
    }
    data.category = f.category;
  }
  if (f.description !== undefined) {
    if (f.description !== null && (typeof f.description !== 'string' || f.description.length > 2000)) {
      return { error: 'Некорректное описание' };
    }
    data.description = f.description;
  }
  if (f.image_url !== undefined) {
    if (f.image_url !== null && f.image_url !== '' && !isHttpUrl(f.image_url)) {
      return { error: 'Некорректная ссылка на картинку' };
    }
    data.image_url = f.image_url === '' ? null : f.image_url;
  }
  if (create || f.price !== undefined) {
    if (!isMoney(f.price)) return { error: 'Некорректная цена' };
    data.price = Number(f.price);
  }
  if (f.weight !== undefined) {
    const w = f.weight;
    const ok =
      w === null ||
      (typeof w === 'number' && Number.isFinite(w)) ||
      (typeof w === 'string' && w.length <= 50);
    if (!ok) return { error: 'Некорректный вес' };
    data.weight = w;
  }
  if (f.is_available !== undefined) {
    if (typeof f.is_available !== 'boolean') return { error: 'is_available должен быть true или false' };
    data.is_available = f.is_available;
  }
  for (const key of ['sizes', 'modifiers']) {
    if (f[key] !== undefined) {
      const json = normalizeJsonArray(f[key]);
      if (json === null) return { error: `Некорректное поле ${key}` };
      data[key] = json;
    }
  }
  return { data };
}

app.get('/api/shops/:shopId/products', needShop, async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ error: 'Неверный ID заведения' });
    }
    const result = await pool.query(
      'SELECT * FROM products WHERE shop_id = $1 ORDER BY id DESC LIMIT 1000',
      [shopId]
    );
    res.json({ products: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при загрузке меню' });
  }
});

app.post('/api/shops/:shopId/products', needShop, async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ error: 'Неверный ID заведения' });
    }

    const { error, data } = validateProductFields(req.body || {}, { create: true });
    if (error) return res.status(400).json({ error });

    const query = `
      INSERT INTO products
      (shop_id, title, category, description, image_url, price, weight, is_available, sizes, modifiers)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
      RETURNING *;
    `;

    const values = [
      shopId,
      data.title,
      data.category ?? null,
      data.description ?? null,
      data.image_url ?? null,
      data.price,
      data.weight ?? null,
      data.is_available ?? true,
      data.sizes ?? '[]',
      data.modifiers ?? '[]',
    ];

    const result = await pool.query(query, values);
    res.status(201).json({ success: true, product: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при создании товара' });
  }
});

app.patch('/api/products/:productId', needShop, async (req, res) => {
  try {
    const productId = toId(req.params.productId);
    if (productId === null) {
      return res.status(400).json({ error: 'Неверный ID товара' });
    }

    const { error, data } = validateProductFields(req.body || {}, { create: false });
    if (error) return res.status(400).json({ error });

    // Имена колонок берутся только из проверенного объекта data (защита от SQL-инъекции)
    const keys = Object.keys(data);
    if (keys.length === 0) {
      return res.status(400).json({ error: 'Нет полей для обновления' });
    }

    const setClauses = keys.map((key, index) => `${key} = $${index + 1}`);
    const values = keys.map((key) => data[key]);

    values.push(productId);
    const idIdx = values.length;
    values.push(req.shop.id);
    const shopIdx = values.length;

    // Магазин правит только свои товары
    const result = await pool.query(
      `UPDATE products SET ${setClauses.join(', ')} WHERE id = $${idIdx} AND shop_id = $${shopIdx} RETURNING *;`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Товар не найден' });
    }

    res.json({ success: true, product: result.rows[0] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при обновлении товара' });
  }
});

app.delete('/api/products/:productId', needShop, async (req, res) => {
  try {
    const productId = toId(req.params.productId);
    if (productId === null) {
      return res.status(400).json({ error: 'Неверный ID товара' });
    }

    // Магазин удаляет только свои товары
    const result = await pool.query(
      'DELETE FROM products WHERE id = $1 AND shop_id = $2 RETURNING id;',
      [productId, req.shop.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Товар не найден' });
    }

    res.json({ success: true, message: 'Товар успешно удален' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при удалении товара' });
  }
});

app.get('/api/shops/:shopId/orders', needShop, async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ error: 'Неверный ID заведения' });
    }
    const result = await pool.query(
      'SELECT * FROM orders WHERE shop_id = $1 ORDER BY created_at DESC LIMIT 500',
      [shopId]
    );
    res.json({ orders: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при загрузке заказов' });
  }
});

// GET /api/shops/:shopId - информация о магазине (только безопасные поля)
app.get('/api/shops/:shopId', async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ error: 'Неверный ID заведения' });
    }

    const result = await pool.query('SELECT * FROM shops WHERE id = $1', [shopId]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Магазин не найден' });
    }

    const shop = result.rows[0];
    const isOwner = req.shop && String(req.shop.id) === String(shop.id);

    // Скрытые магазины видит только сам владелец
    if (shop.is_active !== true && !isOwner) {
      return res.status(404).json({ error: 'Магазин не найден' });
    }

    // Белый список полей: хэш пароля и всё лишнее наружу не уходит
    const publicFields = ['id', 'name', 'category', 'logo_url', 'time', 'is_online', 'is_active', 'phone', 'lat', 'lng'];
    const out = {};
    for (const f of publicFields) out[f] = shop[f];
    if (isOwner) out.login = shop.login; // логин видит только владелец

    res.json(out);
  } catch (err) {
    console.error('Ошибка при получении данных магазина:', err);
    res.status(500).json({ error: 'Ошибка сервера' });
  }
});

// ==========================================
// СОЗДАНИЕ МАГАЗИНОВ
// ==========================================

function toMicroDegrees(value) {
  const n = Number(value);
  return Number.isFinite(n) ? Math.round(n * 1000000) : 0;
}

// --- ЗАЯВКА ЗАВЕДЕНИЯ ---
// Магазин создаётся НЕактивным и со случайным паролем.
// Админ подтверждает его через POST /api/admin/shops/:shopId/approve и получает временный пароль.
app.post('/api/business-requests', businessRequestLimiter, async (req, res) => {
  try {
    const {
      business_name,
      contact_email,
      phone,
      time_schedule,
      logo_url,
      category_key,
      lat,
      lng,
    } = req.body || {};

    if (!isNonEmptyString(business_name, 200)) {
      return res.status(400).json({ success: false, error: 'Укажите название заведения' });
    }
    if (contact_email && !isEmail(contact_email)) {
      return res.status(400).json({ success: false, error: 'Некорректный email' });
    }
    if (phone && !isPhone(phone)) {
      return res.status(400).json({ success: false, error: 'Некорректный телефон' });
    }
    if (logo_url && !isHttpUrl(logo_url)) {
      return res.status(400).json({ success: false, error: 'Некорректная ссылка на логотип' });
    }
    if ((lat && !isLat(lat)) || (lng && !isLng(lng))) {
      return res.status(400).json({ success: false, error: 'Некорректные координаты' });
    }

    const intLat = lat ? toMicroDegrees(lat) : 0;
    const intLng = lng ? toMicroDegrees(lng) : 0;

    const defaultLogin =
      (contact_email && contact_email.trim()) ||
      (phone && phone.trim()) ||
      `shop_${crypto.randomBytes(4).toString('hex')}`;
    const passwordHash = await bcrypt.hash(randomPassword(), 10); // пароль никому не известен до подтверждения

    const query = `
      INSERT INTO shops (
        name, category, login, password_hash, phone, logo_url, lat, lng, time, is_active, is_online
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, false, false)
      RETURNING id
    `;

    const values = [
      business_name.trim(),
      strOrNull(category_key, 50),
      defaultLogin,
      passwordHash,
      strOrNull(phone, 30),
      logo_url || null,
      intLat,
      intLng,
      strOrNull(time_schedule, 100),
    ];

    const result = await pool.query(query, values);

    res.json({
      success: true,
      shopId: result.rows[0].id,
      message: 'Заявка принята. После проверки мы свяжемся с вами и выдадим доступ',
    });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ success: false, error: 'Заявка с такими контактами уже существует' });
    }
    console.error('Ошибка при создании магазина из заявки:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при сохранении заявки' });
  }
});

// --- АДМИН: ПОДТВЕРДИТЬ ЗАЯВКУ / СБРОСИТЬ ПАРОЛЬ МАГАЗИНА ---
app.post('/api/admin/shops/:shopId/approve', adminLimiter, needAdmin, async (req, res) => {
  try {
    const shopId = toId(req.params.shopId);
    if (shopId === null) {
      return res.status(400).json({ success: false, error: 'Неверный ID заведения' });
    }
    const tempPassword = randomPassword();
    const hash = await bcrypt.hash(tempPassword, 10);

    const result = await pool.query(
      'UPDATE shops SET is_active = true, is_online = true, password_hash = $1 WHERE id = $2 RETURNING id, name, login',
      [hash, shopId]
    );
    if (!result.rows.length) {
      return res.status(404).json({ success: false, error: 'Магазин не найден' });
    }
    // Временный пароль показывается один раз: передайте его владельцу, он сменит его в приложении
    res.json({ success: true, shop: result.rows[0], tempPassword });
  } catch (err) {
    console.error('Ошибка подтверждения магазина:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});

// --- ДОБАВЛЕНИЕ МАГАЗИНА (только админ) ---
app.post('/api/shops', adminLimiter, needAdmin, async (req, res) => {
  try {
    const { name, category, login, phone, time, logo_url, lat, lng } = req.body || {};

    if (!isNonEmptyString(name, 200)) {
      return res.status(400).json({ success: false, error: 'Укажите название магазина' });
    }
    const shopLogin = strOrNull(login, 254) || strOrNull(phone, 30);
    if (!shopLogin) {
      return res.status(400).json({ success: false, error: 'Укажите логин или телефон' });
    }
    if (logo_url && !isHttpUrl(logo_url)) {
      return res.status(400).json({ success: false, error: 'Некорректная ссылка на логотип' });
    }
    if ((lat && !isLat(lat)) || (lng && !isLng(lng))) {
      return res.status(400).json({ success: false, error: 'Некорректные координаты' });
    }

    const tempPassword = randomPassword();
    const hash = await bcrypt.hash(tempPassword, 10);

    const query = `
      INSERT INTO shops (name, category, login, password_hash, phone, logo_url, lat, lng, time, is_active, is_online)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, true)
      RETURNING id, name, category, login
    `;

    const values = [
      name.trim(),
      strOrNull(category, 50),
      shopLogin,
      hash,
      strOrNull(phone, 30),
      logo_url || null,
      lat ? toMicroDegrees(lat) : 0, // как и в заявках: координаты хранятся в микроградусах
      lng ? toMicroDegrees(lng) : 0,
      strOrNull(time, 100),
    ];
    const result = await pool.query(query, values);

    res.json({ success: true, shop: result.rows[0], tempPassword });
  } catch (err) {
    if (err.code === '23505') {
      return res.status(409).json({ success: false, error: 'Магазин с таким логином уже существует' });
    }
    console.error('Ошибка при создании магазина:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при создании магазина' });
  }
});

// ==========================================
// ОБРАБОТКА ОШИБОК
// ==========================================

app.use((req, res) => {
  res.status(404).json({ success: false, error: 'Маршрут не найден' });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err && err.type === 'entity.parse.failed') {
    return res.status(400).json({ success: false, error: 'Некорректный JSON в запросе' });
  }
  if (err && err.type === 'entity.too.large') {
    return res.status(413).json({ success: false, error: 'Слишком большой запрос' });
  }
  console.error('Необработанная ошибка:', err);
  res.status(500).json({ success: false, error: 'Ошибка сервера' });
});

process.on('unhandledRejection', (reason) => {
  console.error('unhandledRejection:', reason);
});
process.on('uncaughtException', (err) => {
  console.error('uncaughtException:', err);
  process.exit(1); // pm2 / systemd перезапустят процесс
});

const PORT = Number(process.env.PORT) || 3000;
// По умолчанию слушаем только localhost: наружу выходит один nginx с HTTPS.
// Временно для тестов без nginx можно поставить HOST=0.0.0.0
const HOST = process.env.HOST || '127.0.0.1';
app.listen(PORT, HOST, () => {
  console.log(`Server started on ${HOST}:${PORT}`);
});