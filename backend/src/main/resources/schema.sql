-- =====================================================================
-- VTube database schema (SQLite)
-- Chạy tự động mỗi lần backend khởi động (IF NOT EXISTS nên không mất dữ liệu).
-- Thời gian lưu dạng chuỗi ISO-8601 UTC, ví dụ 2026-10-22T04:30:00Z
-- Muốn làm lại DB từ đầu: tắt backend, xóa file vtube.db, chạy lại.
-- =====================================================================

CREATE TABLE IF NOT EXISTS users (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    email           TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    password_hash   TEXT    NOT NULL,
    display_name    TEXT    NOT NULL,
    avatar_url      TEXT,
    history_paused  INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

-- Mỗi user có đúng 1 kênh, tạo cùng lúc khi đăng ký
CREATE TABLE IF NOT EXISTS channels (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id           INTEGER NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    name              TEXT    NOT NULL,
    handle            TEXT    NOT NULL UNIQUE COLLATE NOCASE,
    description       TEXT,
    avatar_url        TEXT,
    banner_url        TEXT,
    verified          INTEGER NOT NULL DEFAULT 0,
    subscriber_count  INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS categories (
    id    INTEGER PRIMARY KEY,
    name  TEXT NOT NULL,
    slug  TEXT NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS videos (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id        INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    title             TEXT    NOT NULL,
    description       TEXT,
    thumbnail_url     TEXT,
    video_url         TEXT    NOT NULL,
    duration_seconds  INTEGER NOT NULL DEFAULT 0,
    view_count        INTEGER NOT NULL DEFAULT 0,
    like_count        INTEGER NOT NULL DEFAULT 0,
    dislike_count     INTEGER NOT NULL DEFAULT 0,
    comment_count     INTEGER NOT NULL DEFAULT 0,
    category_id       INTEGER REFERENCES categories(id),
    is_short          INTEGER NOT NULL DEFAULT 0,
    is_live           INTEGER NOT NULL DEFAULT 0,
    visibility        TEXT    NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','unlisted','private')),
    comments_enabled  INTEGER NOT NULL DEFAULT 1,
    made_for_kids     INTEGER NOT NULL DEFAULT 0,
    tags              TEXT,
    published_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_videos_channel   ON videos(channel_id);
CREATE INDEX IF NOT EXISTS idx_videos_published ON videos(published_at);

-- value: 1 = like, -1 = dislike
CREATE TABLE IF NOT EXISTS video_reactions (
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    video_id    INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    value       INTEGER NOT NULL CHECK (value IN (1,-1)),
    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (user_id, video_id)
);

CREATE TABLE IF NOT EXISTS comments (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id     INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    parent_id    INTEGER REFERENCES comments(id) ON DELETE CASCADE,
    content      TEXT    NOT NULL,
    like_count   INTEGER NOT NULL DEFAULT 0,
    reply_count  INTEGER NOT NULL DEFAULT 0,
    is_pinned    INTEGER NOT NULL DEFAULT 0,
    is_hearted   INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT
);
CREATE INDEX IF NOT EXISTS idx_comments_video  ON comments(video_id);
CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments(parent_id);

CREATE TABLE IF NOT EXISTS comment_reactions (
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    comment_id  INTEGER NOT NULL REFERENCES comments(id) ON DELETE CASCADE,
    value       INTEGER NOT NULL CHECK (value IN (1,-1)),
    PRIMARY KEY (user_id, comment_id)
);

-- notify_mode: all | personalized | none
CREATE TABLE IF NOT EXISTS subscriptions (
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel_id   INTEGER NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    notify_mode  TEXT    NOT NULL DEFAULT 'personalized' CHECK (notify_mode IN ('all','personalized','none')),
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (user_id, channel_id)
);

-- kind: liked (Video đã thích) | watch_later (Xem sau) | custom (người dùng tự tạo)
CREATE TABLE IF NOT EXISTS playlists (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title        TEXT    NOT NULL,
    description  TEXT,
    visibility   TEXT    NOT NULL DEFAULT 'private' CHECK (visibility IN ('public','unlisted','private')),
    kind         TEXT    NOT NULL DEFAULT 'custom' CHECK (kind IN ('liked','watch_later','custom')),
    created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    updated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);

CREATE TABLE IF NOT EXISTS playlist_videos (
    playlist_id  INTEGER NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    video_id     INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    position     INTEGER NOT NULL DEFAULT 0,
    added_at     TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (playlist_id, video_id)
);

CREATE TABLE IF NOT EXISTS watch_history (
    user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    video_id          INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    progress_seconds  INTEGER NOT NULL DEFAULT 0,
    watched_at        TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (user_id, video_id)
);

CREATE TABLE IF NOT EXISTS search_history (
    user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    keyword      TEXT    NOT NULL COLLATE NOCASE,
    searched_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    PRIMARY KEY (user_id, keyword)
);

-- Video người dùng bấm "Không quan tâm" -> ẩn khỏi feed
CREATE TABLE IF NOT EXISTS hidden_videos (
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    video_id  INTEGER NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, video_id)
);

-- type: new_video | new_short | live | comment_reply | comment_heart | new_subscriber
CREATE TABLE IF NOT EXISTS notifications (
    id                INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id           INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type              TEXT    NOT NULL,
    actor_channel_id  INTEGER REFERENCES channels(id) ON DELETE CASCADE,
    video_id          INTEGER REFERENCES videos(id) ON DELETE CASCADE,
    comment_id        INTEGER REFERENCES comments(id) ON DELETE CASCADE,
    message           TEXT    NOT NULL,
    is_read           INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id, created_at);

-- Token đăng nhập (opaque token, hết hạn sau 30 ngày)
CREATE TABLE IF NOT EXISTS auth_tokens (
    token       TEXT    PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now')),
    expires_at  TEXT    NOT NULL
);
