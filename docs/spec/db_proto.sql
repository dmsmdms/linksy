PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA temp_store = MEMORY;
PRAGMA foreign_keys = ON;
PRAGMA cache_size = -20000;       -- ~20MB RAM cache
PRAGMA mmap_size = 268435456;     -- 256MB mmap
PRAGMA auto_vacuum = INCREMENTAL;

-- ====================================================
-- 1️⃣ USERS — информация о пользователях
-- ====================================================
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,           -- уникальный идентификатор
    telegram_id INTEGER NOT NULL UNIQUE,           -- ID пользователя Telegram
    username TEXT,                                 -- никнейм в Telegram
    full_name TEXT NOT NULL,                        -- полное имя пользователя
    birth_date INTEGER,                             -- дата рождения, Unix timestamp
    gender INTEGER DEFAULT 0,                       -- ENUM: 0 unknown, 1 male, 2 female, 3 other
    bio TEXT,                                      -- описание профиля (About Me)
    location_lat REAL,                             -- широта пользователя
    location_lon REAL,                             -- долгота пользователя
    stars INTEGER DEFAULT 0,                        -- количество звезд (ранг/достижения)
    xp INTEGER DEFAULT 0,                           -- опыт (XP)
    is_blocked INTEGER DEFAULT 0,                  -- блокировка пользователя админом
    is_deleted INTEGER DEFAULT 0,                  -- удалён ли аккаунт
    created_at INTEGER NOT NULL,                   -- время создания (Unix timestamp)
    updated_at INTEGER NOT NULL                    -- время последнего обновления профиля
);

-- Индексы для быстрого поиска и фильтрации
CREATE INDEX idx_users_telegram_id ON users(telegram_id);
CREATE INDEX idx_users_blocked ON users(is_blocked);


-- ====================================================
-- 2️⃣ USER_AVATARS — аватарки пользователя
-- ====================================================
CREATE TABLE user_avatars (
    id INTEGER PRIMARY KEY AUTOINCREMENT,          -- уникальный ID аватарки
    user_id INTEGER NOT NULL,                       -- ссылка на пользователя
    file_path TEXT NOT NULL,                        -- путь к файлу аватарки
    position INTEGER NOT NULL DEFAULT 0,           -- порядок отображения аватарок (0 = первая)
    created_at INTEGER NOT NULL,                    -- время добавления аватарки
    FOREIGN KEY(user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_user_avatars_user ON user_avatars(user_id);


-- ====================================================
-- 3️⃣ FOLLOWS — подписки пользователей
-- ====================================================
CREATE TABLE follows (
    follower_id INTEGER NOT NULL,                   -- кто подписался
    following_id INTEGER NOT NULL,                  -- на кого подписались
    created_at INTEGER NOT NULL,                    -- когда подписка создана
    PRIMARY KEY (follower_id, following_id),
    FOREIGN KEY(follower_id) REFERENCES users(id),
    FOREIGN KEY(following_id) REFERENCES users(id)
);


-- ====================================================
-- 4️⃣ EVENTS — события
-- ====================================================
CREATE TABLE events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,           -- уникальный ID события
    creator_id INTEGER NOT NULL,                     -- создатель события (user_id)
    title TEXT NOT NULL,                             -- название события
    description TEXT,                               -- описание события
    start_datetime INTEGER NOT NULL,                -- дата и время начала, Unix timestamp
    end_datetime INTEGER NOT NULL,                  -- дата и время окончания, Unix timestamp
    is_multiday INTEGER DEFAULT 0,                  -- многодневное событие (0/1)
    is_private INTEGER DEFAULT 0,                   -- приватное событие (0/1)
    gender_restriction INTEGER DEFAULT 0,           -- 0 все, 1 муж, 2 жен, 3 другой
    age_min INTEGER,                                -- минимальный возраст участников
    age_max INTEGER,                                -- максимальный возраст участников
    max_participants INTEGER,                        -- максимальное количество участников
    price INTEGER DEFAULT 0,                         -- цена участия
    location_lat REAL NOT NULL,                      -- широта события
    location_lon REAL NOT NULL,                      -- долгота события
    likes_count INTEGER DEFAULT 0,                  -- количество лайков (кэш для быстрого чтения)
    participants_count INTEGER DEFAULT 0,          -- количество участников (кэш)
    created_at INTEGER NOT NULL,                    -- время создания события
    updated_at INTEGER NOT NULL,                    -- время последнего обновления
    is_archived INTEGER DEFAULT 0,                  -- перенесено в архив после завершения
    FOREIGN KEY(creator_id) REFERENCES users(id)
);

CREATE INDEX idx_events_creator ON events(creator_id);
CREATE INDEX idx_events_start ON events(start_datetime);
CREATE INDEX idx_events_archived ON events(is_archived);


-- ====================================================
-- 5️⃣ EVENT_IMAGES — изображения события
-- ====================================================
CREATE TABLE event_images (
    id INTEGER PRIMARY KEY AUTOINCREMENT,          -- уникальный ID изображения
    event_id INTEGER NOT NULL,                      -- ссылка на событие
    file_path TEXT NOT NULL,                         -- путь к файлу изображения
    position INTEGER DEFAULT 0,                      -- порядок отображения
    created_at INTEGER NOT NULL,                     -- время добавления
    FOREIGN KEY(event_id) REFERENCES events(id) ON DELETE CASCADE
);


-- ====================================================
-- 6️⃣ EVENT_PARTICIPANTS — участники события
-- ====================================================
CREATE TABLE event_participants (
    event_id INTEGER NOT NULL,                      -- событие
    user_id INTEGER NOT NULL,                        -- пользователь
    status INTEGER NOT NULL,                         -- 1 joined, 2 requested
    created_at INTEGER NOT NULL,                     -- когда пользователь присоединился
    PRIMARY KEY(event_id, user_id),
    FOREIGN KEY(event_id) REFERENCES events(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
);

CREATE INDEX idx_event_participants_event ON event_participants(event_id);


-- ====================================================
-- 7️⃣ EVENT_LIKES — лайки события
-- ====================================================
CREATE TABLE event_likes (
    event_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY(event_id, user_id),
    FOREIGN KEY(event_id) REFERENCES events(id),
    FOREIGN KEY(user_id) REFERENCES users(id)
);


-- ====================================================
-- 8️⃣ EVENT_INVITES — приглашения на событие
-- ====================================================
CREATE TABLE event_invites (
    event_id INTEGER NOT NULL,
    invited_user_id INTEGER NOT NULL,
    invited_by INTEGER NOT NULL,                     -- кто пригласил
    status INTEGER DEFAULT 0,                        -- 0 pending, 1 accepted, 2 declined
    created_at INTEGER NOT NULL,
    PRIMARY KEY(event_id, invited_user_id)
);


-- ====================================================
-- 9️⃣ EVENT_TRANSLATIONS — переводы описания события
-- ====================================================
CREATE TABLE event_translations (
    event_id INTEGER NOT NULL,
    language INTEGER NOT NULL,                          -- ISO код языка
    translated_description TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    PRIMARY KEY(event_id, language)
);


-- ====================================================
-- 🔟 CHATS — чаты
-- ====================================================
CREATE TABLE chats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type INTEGER NOT NULL,                           -- 1 private, 2 event
    event_id INTEGER,                                -- ссылка на событие (для группового чата)
    created_at INTEGER NOT NULL,
    FOREIGN KEY(event_id) REFERENCES events(id)
);

CREATE INDEX idx_chats_event ON chats(event_id);


-- ====================================================
-- 11️⃣ CHAT_PARTICIPANTS — участники чата
-- ====================================================
CREATE TABLE chat_participants (
    chat_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    last_read_message_id INTEGER,                   -- последний прочитанный ID
    PRIMARY KEY(chat_id, user_id)
);


-- ====================================================
-- 12️⃣ MESSAGES — сообщения чата
-- ====================================================
CREATE TABLE messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chat_id INTEGER NOT NULL,
    sender_id INTEGER NOT NULL,
    text TEXT,
    created_at INTEGER NOT NULL,                     -- время отправки
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY(chat_id) REFERENCES chats(id)
);

CREATE INDEX idx_messages_chat ON messages(chat_id);
CREATE INDEX idx_messages_created ON messages(created_at);


-- ====================================================
-- 13️⃣ NOTIFICATIONS — нотификации
-- ====================================================
CREATE TABLE notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    type INTEGER NOT NULL,                          -- тип уведомления
    reference_id INTEGER,                            -- ссылка на объект (событие, сообщение)
    is_read INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

CREATE INDEX idx_notifications_user ON notifications(user_id);


-- ====================================================
-- 14️⃣ STORIES — истории пользователей
-- ====================================================
CREATE TABLE stories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    file_path TEXT,
    event_id INTEGER,                               -- если история привязана к событию
    expires_at INTEGER NOT NULL,                     -- дата окончания истории (Unix timestamp)
    created_at INTEGER NOT NULL
);

CREATE INDEX idx_stories_expires ON stories(expires_at);


-- ====================================================
-- 15️⃣ FEEDBACK — обратная связь
-- ====================================================
CREATE TABLE feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,                                -- необязательный
    message TEXT NOT NULL,
    created_at INTEGER NOT NULL
);


-- ====================================================
-- 16️⃣ SYSTEM_SETTINGS — системные настройки
-- ====================================================
CREATE TABLE system_settings (
    key TEXT PRIMARY KEY,                            -- название настройки
    value TEXT                                        -- значение
);

