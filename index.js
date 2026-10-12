const express = require('express');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

// --- Проверка, что .env подхватился ---
if (!process.env.JWT_SECRET || !process.env.DB_PASSWORD) {
  console.error('❌ В файле .env нет JWT_SECRET или DB_PASSWORD. Сервер не запущен.');
  process.exit(1);
}

const app = express();
app.use(express.json());
app.use(cors());

// Подключение к PostgreSQL
// Подключение к PostgreSQL
const pool = new Pool({
  user: 'delivery_user',
  host: 'localhost',
  database: 'delivery',
  password: process.env.DB_PASSWORD,
  port: 5432,
});
const JWT_SECRET = process.env.JWT_SECRET;

// ==========================================
// АВТОРИЗАЦИЯ
// ==========================================
// STRICT_AUTH=false (по умолчанию) -> старые роуты работают как раньше, без токена.
// STRICT_AUTH=true  -> защищённые роуты требуют токен (включай, когда приложение
//                      начнёт слать заголовок Authorization: Bearer <token>).
const STRICT = process.env.STRICT_AUTH === 'true';

// --- Старый middleware: токен обязателен всегда (используется в 3 роутах) ---
function verifyToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // Ожидаем формат "Bearer TOKEN"

  if (!token) {
    return res.status(401).json({ success: false, error: 'Требуется авторизация (нет токена)' });
  }

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Недействительный или просроченный токен' });
    }

    req.user = {
      id: decoded.userId || decoded.id
    };

    next();
  });
}

// --- Мягкий разбор токена для всех роутов: заполняет req.user / req.shop, если токен есть ---
function softAuth(req, res, next) {
  const token = (req.headers['authorization'] || '').split(' ')[1];
  if (!token) return next();

  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      if (STRICT) return res.status(403).json({ success: false, error: 'Недействительный или просроченный токен' });
      return next();
    }
    if (decoded.userId || decoded.id) req.user = { id: decoded.userId || decoded.id };
    if (decoded.shopId) req.shop = { id: decoded.shopId };
    next();
  });
}
app.use(softAuth);

// Нужен вошедший клиент (в STRICT-режиме)
function needUser(req, res, next) {
  if (!STRICT) return next();
  if (!req.user) return res.status(401).json({ success: false, error: 'Требуется вход клиента' });
  next();
}

// Нужен вошедший магазин (в STRICT-режиме), и это именно его магазин
function needShop(req, res, next) {
  if (!STRICT) return next();
  if (!req.shop) return res.status(401).json({ success: false, error: 'Требуется вход магазина' });
  if (req.params.shopId && String(req.shop.id) !== String(req.params.shopId)) {
    return res.status(403).json({ success: false, error: 'Это чужой магазин' });
  }
  next();
}

// Подойдёт и клиент, и магазин
function needAny(req, res, next) {
  if (!STRICT) return next();
  if (!req.user && !req.shop) return res.status(401).json({ success: false, error: 'Требуется авторизация' });
  next();
}

// Только админ (по ключу из .env: ADMIN_KEY), в STRICT-режиме
function needAdmin(req, res, next) {
  if (!STRICT) return next();
  const key = req.headers['x-admin-key'];
  if (!process.env.ADMIN_KEY || key !== process.env.ADMIN_KEY) {
    return res.status(403).json({ success: false, error: 'Только для администратора' });
  }
  next();
}

// Тестовый роут
app.get('/', (req, res) => {
  res.json({ message: 'Server is running and connected to PostgreSQL!' });
});





// --- 1. РЕГИСТРАЦИЯ ---
app.post('/api/register', async (req, res) => {
  try {
    const { name, email, phone, password, role } = req.body;

    if (!password) {
      return res.status(400).json({ success: false, error: 'Введите пароль' });
    }

    const saltRounds = 10;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Нельзя зарегистрироваться как admin через открытый роут
    const safeRole = (!role || role === 'admin') ? 'client' : role;

    const query = `
      INSERT INTO users (name, email, phone, password_hash, role) 
      VALUES ($1, $2, $3, $4, $5) 
      RETURNING id, name, email, phone, role, created_at
    `;
    const values = [name, email, phone, passwordHash, safeRole];

    const result = await pool.query(query, values);
    const user = result.rows[0];

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });

    res.json({ success: true, token, user });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Ошибка при регистрации (возможно, телефон или email уже заняты)' });
  }
});





// --- 2. ВХОД (ЛОГИН) ---
app.post('/api/login', async (req, res) => {
  try {
    const { phone, password } = req.body;

    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) {
      return res.status(400).json({ success: false, error: 'Пользователь не найден' });
    }

    const user = result.rows[0];

    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный пароль' });
    }

    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '30d' });

    res.json({ 
      success: true, 
      token, 
      user: { 
        id: user.id, 
        name: user.name, 
        email: user.email, 
        phone: user.phone, 
        role: user.role 
      } 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});






// --- Смена пароля ---
app.post('/api/auth/change-password', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id; 
    const { oldPassword, newPassword } = req.body;

    if (!oldPassword || !newPassword) {
      return res.status(400).json({ success: false, error: 'Заполните все поля' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, error: 'Новый пароль слишком короткий (мин. 6 символов)' });
    }

    // 1. Ищем пользователя в БД по id
    const userResult = await pool.query('SELECT * FROM users WHERE id = $1', [userId]);
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Пользователь не найден' });
    }

    const user = userResult.rows[0];

    // 2. Сверяем старый пароль с тем, что хранится в password_hash
    const isMatch = await bcrypt.compare(oldPassword, user.password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный старый пароль' });
    }

    // 3. Хэшируем новый пароль
    const salt = await bcrypt.genSalt(10);
    const newPasswordHash = await bcrypt.hash(newPassword, salt);

    // 4. Обновляем password_hash в таблице users
    await pool.query(
      'UPDATE users SET password_hash = $1 WHERE id = $2',
      [newPasswordHash, userId]
    );

    res.json({ success: true, message: 'Пароль успешно изменён' });

  } catch (err) {
    console.error('Ошибка при смене пароля:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});





// --- СОЗДАНИЕ ЗАКАЗА ---
app.post('/api/orders', needUser, async (req, res) => {
  try {
    const orderData = req.body;

    // Если клиент вошёл по токену — user_id берём из токена, а не из тела запроса
    const orderUserId = req.user ? req.user.id : orderData.user_id;

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
      orderData.shop_id,
      orderData.type,
      orderData.category,
      orderData.status || 'new',
      orderData.client_name,
      orderData.client_phone,
      orderData.client_address,
      orderData.client_lat,
      orderData.client_lng,
      orderData.restaurant_name,
      orderData.restaurant_image || '', // 🔹 Добавили картинку ресторана
      orderData.restaurant_address,
      orderData.restaurant_lat,
      orderData.restaurant_lng,
      orderData.restaurant_comment,
      orderData.delivery_lat,
      orderData.delivery_lng,
      orderData.delivery_price,
      orderData.distance_km,
      orderData.duration_min,
      orderData.items_price,
      orderData.total_price,
      orderData.payment_method,
      orderData.comment,
      JSON.stringify(orderData.replacements) // Сдвинулся на $26
    ];

    const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      orderId: result.rows[0].id,
      message: 'Заказ успешно создан'
    });

  } catch (error) {
    console.error('Ошибка при создании заказа:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});





// Получение списка всех заведений/магазинов
app.get('/api/shops', async (req, res) => {
    try {
        const result = await pool.query(
            'SELECT id, name, category, logo_url, time, is_online FROM shops WHERE is_active = true'
        );

        res.json({
            success: true,
            shops: result.rows.map(shop => ({
                id: shop.id,
                title: shop.name,
                category: shop.category,
                image_url: shop.logo_url,
                time: shop.time,
                is_online: shop.is_online
            }))
        });
    } catch (err) {
        console.error('Ошибка при получении заведений:', err);
        res.status(500).json({ success: false, error: 'Ошибка сервера' });
    }
});




// Получение меню конкретного заведения по shopId
app.get('/api/shops/:shopId/menu', async (req, res) => {
    try {
        const { shopId } = req.params;
        
        const result = await pool.query(
            'SELECT id, title AS name, category, price, weight, description, image_url, is_available, sizes, modifiers FROM products WHERE shop_id = $1',
            [shopId]
        );

        res.json({
            success: true,
            menu: result.rows.map(dish => ({
                id: dish.id,
                name: dish.name,
                category: dish.category,
                price: dish.price,
                weight: dish.weight,
                description: dish.description,
                imagePath: dish.image_url,
                isAvailable: dish.is_available,
                size: dish.sizes,
                modifiers: dish.modifiers
            }))
        });
    } catch (err) {
        console.error('Ошибка при получении меню:', err);
        res.status(500).json({ success: false, error: err.message });
    }
});



// --- ИСТОРИЯ ЗАКАЗОВ КЛИЕНТА ---
app.get('/api/orders/user/:userId', needUser, async (req, res) => {
  try {
    let { userId } = req.params;

    // Если прислали объект в виде строки, вытаскиваем оттуда число после id:
    if (userId.includes('{') || userId.includes('id')) {
      const match = userId.match(/id:\s*(\d+)/);
      if (match) {
        userId = match[1];
      }
    }

    const numericUserId = parseInt(userId, 10);
    if (isNaN(numericUserId)) {
      return res.status(400).json({ success: false, error: 'Неверный формат ID пользователя' });
    }

    // В строгом режиме клиент видит только свои заказы
    if (STRICT && req.user && Number(req.user.id) !== numericUserId) {
      return res.status(403).json({ success: false, error: 'Нет доступа к чужим заказам' });
    }

    const query = `SELECT * FROM orders WHERE user_id = $1 ORDER BY created_at DESC;`;
    const result = await pool.query(query, [numericUserId]);

    res.status(200).json({ success: true, orders: result.rows });
  } catch (error) {
    console.error('Ошибка при получении истории заказов:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});








// --- УДАЛИТЬ ОБЫЧНЫЙ ЗАКАЗ ---
app.delete('/api/orders/:id', needUser, async (req, res) => {
  try {
    const { id } = req.params;

    let query = `DELETE FROM orders WHERE id = $1;`;
    let params = [id];

    // В строгом режиме клиент может удалить только свой заказ
    if (STRICT && req.user) {
      query = `DELETE FROM orders WHERE id = $1 AND user_id = $2;`;
      params = [id, req.user.id];
    }

    await pool.query(query, params);
    res.status(200).json({ success: true, message: 'Заказ успешно удален' });
  } catch (error) {
    console.error('Ошибка при удалении заказа:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// --- УДАЛИТЬ ЗАКАЗ ДОСТАВКИ ---
app.delete('/api/delivery-orders/:id', needUser, async (req, res) => {
  try {
    const { id } = req.params;
    const query = `DELETE FROM delivery_orders WHERE id = $1;`;
    await pool.query(query, [id]);
    res.status(200).json({ success: true, message: 'Доставка успешно удалена' });
  } catch (error) {
    console.error('Ошибка при удалении доставки:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});





app.post('/api/individual-orders', verifyToken, async (req, res) => {
  try {
    const {
      user_id,
      client_id,
      client_name,
      client_phone,
      name,
      phone,
      pickup_address,
      pickup_address_id,
      dropoff_address,
      dropoff_address_id,
      distance_km,
      duration_min,
      total_cost,
      description,
      type,
      sub_type,
      status
    } = req.body;

    const query = `
      INSERT INTO individual_deliveries (
        user_id, client_id, client_name, client_phone, name, phone,
        pickup_address, pickup_address_id, dropoff_address, dropoff_address_id,
        distance_km, duration_min, total_cost, description, type, sub_type, status, created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, NOW())
      RETURNING *;
    `;

    const values = [
      req.user.id || user_id, client_id, client_name, client_phone, name, phone,
      pickup_address, pickup_address_id, dropoff_address, dropoff_address_id,
      distance_km, duration_min, total_cost, description, type, sub_type, status
    ];

    const result = await pool.query(query, values);

    res.status(201).json({
      success: true,
      message: 'Индивидуальная доставка успешно создана',
      order: result.rows[0]
    });
  } catch (error) {
    console.error('Error creating individual order:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера при создании доставки' });
  }
});



app.get('/api/individual-orders', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id || req.query.user_id;
    console.log('=== [GET /individual-orders] Получен запрос для user_id:', userId);

    if (!userId) {
      return res.status(400).json({ success: false, error: 'Не указан user_id' });
    }

    const query = `
      SELECT * FROM individual_deliveries 
      WHERE user_id = $1 
      ORDER BY created_at DESC;
    `;
    
    // Превращаем в integer, так как в базе user_id это integer
    const result = await pool.query(query, [parseInt(userId, 10)]);
    
    console.log(`=== [GET /individual-orders] Найдено записей: ${result.rows.length} ===`);
    res.status(200).json(result.rows);
  } catch (error) {
    console.error('Error fetching individual orders:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});





// --- 4. ВХОД ДЛЯ МАГАЗИНА (ПАРТНЕРА) ---
app.post('/api/shops/login', async (req, res) => {
  try {
    const { login, password } = req.body;

    const result = await pool.query('SELECT * FROM shops WHERE login = $1', [login]);
    if (result.rows.length === 0) {
      return res.status(400).json({ success: false, error: 'Магазин с таким логином не найден' });
    }

    const shop = result.rows[0];

    const isMatch = await bcrypt.compare(password, shop.password_hash);
    if (!isMatch) {
      return res.status(400).json({ success: false, error: 'Неверный пароль' });
    }

    const token = jwt.sign({ shopId: shop.id }, JWT_SECRET, { expiresIn: '30d' });

    res.json({ 
      success: true, 
      token, 
      shop: { 
        id: shop.id, 
        name: shop.name, 
        login: shop.login,
        category: shop.category
      } 
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при входе магазина' });
  }
});

















// ==========================================
// УПРАВЛЕНИЕ ТОВАРАМИ И ЗАКАЗАМИ (МЕНЮ МАГАЗИНА)
// ==========================================

app.get('/api/shops/:shopId/products', needShop, async (req, res) => {
  try {
    const { shopId } = req.params;
    const result = await pool.query(
      'SELECT * FROM products WHERE shop_id = $1 ORDER BY id DESC',
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
    const { shopId } = req.params;
    const {
      title,
      category,
      description,
      image_url,
      price,
      weight,
      is_available,
      sizes,
      modifiers
    } = req.body;

    const query = `
      INSERT INTO products 
      (shop_id, title, category, description, image_url, price, weight, is_available, sizes, modifiers) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) 
      RETURNING *;
    `;

    const values = [
      shopId,
      title,
      category,
      description,
      image_url,
      price,
      weight,
      is_available ?? true,
      JSON.stringify(sizes || []),
      JSON.stringify(modifiers || [])
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
    const { productId } = req.params;
    const fields = req.body;

    // Разрешены только эти колонки (защита от SQL-инъекции через имена полей)
    const allowed = ['title', 'category', 'description', 'image_url', 'price', 'weight', 'is_available', 'sizes', 'modifiers'];
    const keys = Object.keys(fields).filter(k => allowed.includes(k));
    if (keys.length === 0) {
      return res.status(400).json({ error: 'Нет полей для обновления' });
    }

    const setClauses = [];
    const values = [];

    keys.forEach((key, index) => {
      let value = fields[key];
      if ((key === 'sizes' || key === 'modifiers') && typeof value !== 'string') {
        value = JSON.stringify(value);
      }
      setClauses.push(`${key} = $${index + 1}`);
      values.push(value);
    });

    values.push(productId);
    let query = `UPDATE products SET ${setClauses.join(', ')} WHERE id = $${values.length}`;

    // В строгом режиме магазин правит только свои товары
    if (STRICT && req.shop) {
      values.push(req.shop.id);
      query += ` AND shop_id = $${values.length}`;
    }
    query += ' RETURNING *;';

    const result = await pool.query(query, values);

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
    const { productId } = req.params;

    let query = 'DELETE FROM products WHERE id = $1 RETURNING *;';
    let params = [productId];

    // В строгом режиме магазин удаляет только свои товары
    if (STRICT && req.shop) {
      query = 'DELETE FROM products WHERE id = $1 AND shop_id = $2 RETURNING *;';
      params = [productId, req.shop.id];
    }

    const result = await pool.query(query, params);

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
    const { shopId } = req.params;
    const result = await pool.query(
      'SELECT * FROM orders WHERE shop_id = $1 ORDER BY created_at DESC',
      [shopId]
    );
    res.json({ orders: result.rows });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Ошибка сервера при загрузке заказов' });
  }
});




// GET /api/shops/:shopId - Получить информацию о магазине (включая категорию)
app.get('/api/shops/:shopId', async (req, res) => {
    const { shopId } = req.params;
    try {
        const result = await pool.query('SELECT * FROM shops WHERE id = $1', [shopId]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Магазин не найден' });
        }

        // Не отдаём хэш пароля наружу
        const shop = result.rows[0];
        delete shop.password_hash;

        // Возвращаем данные магазина (включая колонку category)
        res.json(shop);
    } catch (err) {
        console.error('Ошибка при получении данных магазина:', err);
        res.status(500).json({ error: 'Ошибка сервера' });
    }
});






// --- ОБНОВЛЕНИЕ ЗАКАЗА (замены, смена статуса) ---
app.patch('/api/orders/:orderId/update', needAny, async (req, res) => {
  try {
    const { orderId } = req.params;
    const updateData = req.body;

    // Разрешены только эти колонки
    const allowed = ['status', 'replacements'];
    const keys = Object.keys(updateData).filter(k => allowed.includes(k));
    if (!keys.length) {
      return res.status(400).json({ success: false, error: 'Нет полей для обновления' });
    }

    const fields = keys.map((k, i) => `${k} = $${i + 1}`);
    const values = keys.map(k =>
      typeof updateData[k] === 'object' ? JSON.stringify(updateData[k]) : updateData[k]
    );
    values.push(orderId);

    const result = await pool.query(
      `UPDATE orders SET ${fields.join(', ')} WHERE id = $${values.length} RETURNING *`,
      values
    );

    if (!result.rows.length) {
      return res.status(404).json({ success: false, error: 'Заказ не найден' });
    }

    res.json({ success: true, order: result.rows[0] });
  } catch (error) {
    console.error('Ошибка обновления заказа:', error);
    res.status(500).json({ success: false, error: 'Ошибка сервера' });
  }
});










// --- ДОБАВЛЕНИЕ ЗАЯВКИ КАК МАГАЗИНА В ТАБЛИЦУ SHOPS ---
app.post('/api/business-requests', async (req, res) => {
  try {
    const {
      business_name,
      contact_email,
      phone,
      address,
      time_schedule,
      logo_url,
      category_key,
      lat,
      lng
    } = req.body;

    const intLat = lat ? Math.round(Number(lat) * 1000000) : 0;
    const intLng = lng ? Math.round(Number(lng) * 1000000) : 0;

    const defaultLogin = contact_email || phone || `shop_${Date.now()}`;
    const saltRounds = 10;
    const defaultPasswordHash = await bcrypt.hash('123456', saltRounds);

    const query = `
      INSERT INTO shops (
        name, category, login, password_hash, phone, logo_url, lat, lng, time, is_active, is_online
      ) 
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, true)
      RETURNING *
    `;

    const values = [
      business_name,
      category_key,
      defaultLogin,
      defaultPasswordHash,
      phone,
      logo_url,
      intLat,
      intLng,
      time_schedule
    ];

    const result = await pool.query(query, values);

    const shop = result.rows[0];
    delete shop.password_hash;
    res.json({ success: true, shop });
  } catch (err) {
    console.error('Ошибка при создании магазина из заявки:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при сохранении магазина' });
  }
});
















// --- ДОБАВЛЕНИЕ НОВОГО МАГАЗИНА В ТАБЛИЦУ SHOPS ---
app.post('/api/shops', needAdmin, async (req, res) => {
  try {
    const { name, category, login, phone, address, time, logo_url, lat, lng } = req.body;

    const saltRounds = 10;
    const defaultPasswordHash = await bcrypt.hash('123456', saltRounds);

    const query = `
      INSERT INTO shops (name, category, login, password_hash, phone, logo_url, lat, lng, time, is_active, is_online)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, true)
      RETURNING *
    `;

    const values = [name, category, login || phone, defaultPasswordHash, phone, logo_url, lat, lng, time];
    const result = await pool.query(query, values);

    const shop = result.rows[0];
    delete shop.password_hash;
    res.json({ success: true, shop });
  } catch (err) {
    console.error('Ошибка при создании магазина:', err);
    res.status(500).json({ success: false, error: 'Ошибка сервера при создании магазина' });
  }
});

const PORT = process.env.PORT || 3100;
app.listen(PORT, () => {
  console.log(`Server started on port ${PORT} | STRICT_AUTH=${STRICT}`);
});
