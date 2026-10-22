package com.vtube.api.channel;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import com.vtube.api.notification.NotificationService;
import com.vtube.api.video.VideoDto;
import com.vtube.api.video.VideoSql;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class ChannelService {
    private final Db db;
    private final NotificationService notifications;

    public ChannelService(Db db, NotificationService notifications) {
        this.db = db;
        this.notifications = notifications;
    }

    public ChannelDto get(Long uid, long id) {
        List<ChannelDto> rows = db.jdbc().query("""
                        SELECT c.*,
                               (SELECT COUNT(*) FROM videos v WHERE v.channel_id = c.id AND v.visibility = 'public') AS video_count,
                               (SELECT COALESCE(SUM(view_count), 0) FROM videos v WHERE v.channel_id = c.id) AS total_views,
                               (SELECT notify_mode FROM subscriptions s WHERE s.channel_id = c.id AND s.user_id = :uid) AS my_mode
                        FROM channels c WHERE c.id = :id""",
                Db.params().addValue("id", id).addValue("uid", uid),
                (rs, i) -> {
                    String mode = rs.getString("my_mode");
                    return new ChannelDto(rs.getLong("id"), rs.getLong("user_id"), rs.getString("name"),
                            rs.getString("handle"), rs.getString("description"), rs.getString("avatar_url"),
                            rs.getString("banner_url"), Db.bool(rs, "verified"), rs.getLong("subscriber_count"),
                            rs.getLong("video_count"), rs.getLong("total_views"), rs.getString("created_at"),
                            mode != null, mode, uid != null && rs.getLong("user_id") == uid);
                });
        if (rows.isEmpty()) {
            throw ApiException.notFound("kênh");
        }
        return rows.get(0);
    }

    public ChannelDto getByHandle(Long uid, String handle) {
        String h = handle.startsWith("@") ? handle.substring(1) : handle;
        List<Long> ids = db.jdbc().query("SELECT id FROM channels WHERE handle = :h",
                Db.params().addValue("h", h), (rs, i) -> rs.getLong(1));
        if (ids.isEmpty()) {
            throw ApiException.notFound("kênh");
        }
        return get(uid, ids.get(0));
    }

    /** sort: newest | popular | oldest. shorts = true để lấy tab Shorts. */
    public PageResult<VideoDto> videos(Long uid, long channelId, boolean shorts, String sort, Paging paging) {
        String order = switch (sort == null ? "newest" : sort) {
            case "popular" -> "v.view_count DESC";
            case "oldest" -> "v.published_at ASC";
            default -> "v.published_at DESC";
        };
        List<VideoDto> rows = db.jdbc().query(
                VideoSql.SELECT + " WHERE v.channel_id = :ch AND v.is_short = :short AND " + VideoSql.VISIBLE
                        + " ORDER BY " + order + " LIMIT :limit OFFSET :offset",
                Db.params().addValue("ch", channelId).addValue("short", shorts ? 1 : 0).addValue("uid", uid)
                        .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset()),
                VideoSql.MAPPER);
        return PageResult.of(rows, paging);
    }

    public record UpdateChannelRequest(String name, String description, String avatarUrl, String bannerUrl) {
    }

    @Transactional
    public ChannelDto updateMine(long uid, UpdateChannelRequest req) {
        db.jdbc().update("""
                        UPDATE channels SET name = COALESCE(:name, name),
                                            description = COALESCE(:desc, description),
                                            avatar_url = COALESCE(:avatar, avatar_url),
                                            banner_url = COALESCE(:banner, banner_url)
                        WHERE user_id = :uid""",
                Db.params().addValue("name", blank(req.name())).addValue("desc", req.description())
                        .addValue("avatar", blank(req.avatarUrl())).addValue("banner", blank(req.bannerUrl()))
                        .addValue("uid", uid));
        if (blank(req.avatarUrl()) != null) {
            db.jdbc().update("UPDATE users SET avatar_url = :a WHERE id = :uid",
                    Db.params().addValue("a", req.avatarUrl()).addValue("uid", uid));
        }
        long id = db.count("SELECT id FROM channels WHERE user_id = :uid", Db.params().addValue("uid", uid));
        return get(uid, id);
    }

    public record SubscriptionResult(boolean subscribed, String notifyMode, long subscriberCount) {
    }

    /** Đăng ký mới hoặc đổi chế độ chuông. notifyMode: all | personalized | none */
    @Transactional
    public SubscriptionResult subscribe(long uid, long channelId, String notifyMode) {
        String mode = notifyMode == null || notifyMode.isBlank() ? "personalized" : notifyMode;
        if (!List.of("all", "personalized", "none").contains(mode)) {
            throw ApiException.badRequest("notifyMode phải là all, personalized hoặc none");
        }
        ChannelDto ch = get(uid, channelId);
        if (ch.mine()) {
            throw ApiException.badRequest("Không thể tự đăng ký kênh của mình");
        }
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("ch", channelId).addValue("mode", mode);
        if (ch.subscribed()) {
            db.jdbc().update("UPDATE subscriptions SET notify_mode = :mode WHERE user_id = :uid AND channel_id = :ch", p);
        } else {
            db.jdbc().update("INSERT INTO subscriptions (user_id, channel_id, notify_mode) VALUES (:uid, :ch, :mode)", p);
            db.jdbc().update("UPDATE channels SET subscriber_count = subscriber_count + 1 WHERE id = :ch", p);
            String myHandle = db.jdbc().queryForObject("SELECT handle FROM channels WHERE user_id = :uid", p, String.class);
            long myChannel = db.count("SELECT id FROM channels WHERE user_id = :uid", p);
            notifications.notifyUser(ch.userId(), "new_subscriber", myChannel, null, null,
                    "@" + myHandle + " đã đăng ký kênh của bạn");
        }
        long count = db.count("SELECT subscriber_count FROM channels WHERE id = :ch", p);
        return new SubscriptionResult(true, mode, count);
    }

    @Transactional
    public SubscriptionResult unsubscribe(long uid, long channelId) {
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("ch", channelId);
        int n = db.jdbc().update("DELETE FROM subscriptions WHERE user_id = :uid AND channel_id = :ch", p);
        if (n > 0) {
            db.jdbc().update("UPDATE channels SET subscriber_count = MAX(0, subscriber_count - 1) WHERE id = :ch", p);
        }
        long count = db.count("SELECT subscriber_count FROM channels WHERE id = :ch", p);
        return new SubscriptionResult(false, null, count);
    }

    /** sort: recent (có video mới nhất trước) | az | relevance (kênh xem nhiều nhất trước) */
    public List<SubscriptionChannelDto> mySubscriptions(long uid, String sort) {
        String order = switch (sort == null ? "recent" : sort) {
            case "az" -> "c.name COLLATE NOCASE ASC";
            case "relevance" -> "watched DESC, last_upload DESC";
            default -> "last_upload DESC";
        };
        return db.jdbc().query("""
                        SELECT c.id, c.name, c.handle, c.avatar_url, c.verified, c.subscriber_count, s.notify_mode,
                               (SELECT MAX(published_at) FROM videos v WHERE v.channel_id = c.id AND v.visibility = 'public') AS last_upload,
                               (SELECT COUNT(*) FROM watch_history h JOIN videos v ON v.id = h.video_id
                                 WHERE h.user_id = :uid AND v.channel_id = c.id) AS watched,
                               EXISTS (SELECT 1 FROM videos v WHERE v.channel_id = c.id AND v.visibility = 'public'
                                         AND v.published_at >= strftime('%Y-%m-%dT%H:%M:%SZ','now','-7 days')
                                         AND v.id NOT IN (SELECT video_id FROM watch_history WHERE user_id = :uid)) AS has_new
                        FROM subscriptions s JOIN channels c ON c.id = s.channel_id
                        WHERE s.user_id = :uid
                        ORDER BY\s""" + order,
                Db.params().addValue("uid", uid),
                (rs, i) -> new SubscriptionChannelDto(
                        new ChannelBrief(rs.getLong("id"), rs.getString("name"), rs.getString("handle"),
                                rs.getString("avatar_url"), Db.bool(rs, "verified"), rs.getLong("subscriber_count")),
                        rs.getString("notify_mode"), Db.bool(rs, "has_new"), rs.getString("last_upload")));
    }

    /**
     * Feed kênh đăng ký. channelId (tùy chọn) để lọc 1 kênh.
     * type: all | today | video | short | live | continue (đang xem dở) | unwatched
     */
    public PageResult<VideoDto> subscriptionFeed(long uid, Long channelId, String type, Paging paging) {
        StringBuilder where = new StringBuilder("""
                 WHERE v.visibility = 'public'
                   AND v.channel_id IN (SELECT channel_id FROM subscriptions WHERE user_id = :uid)\s""");
        MapSqlParameterSource p = Db.params().addValue("uid", uid)
                .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset());
        if (channelId != null) {
            where.append(" AND v.channel_id = :ch ");
            p.addValue("ch", channelId);
        }
        switch (type == null ? "all" : type) {
            case "today" -> where.append(" AND v.published_at >= strftime('%Y-%m-%dT%H:%M:%SZ','now','-1 day') ");
            case "video" -> where.append(" AND v.is_short = 0 ");
            case "short" -> where.append(" AND v.is_short = 1 ");
            case "live" -> where.append(" AND v.is_live = 1 ");
            case "continue" -> where.append("""
                     AND v.id IN (SELECT video_id FROM watch_history WHERE user_id = :uid AND progress_seconds > 0)
                     AND v.is_short = 0\s""");
            case "unwatched" -> where.append(" AND v.id NOT IN (SELECT video_id FROM watch_history WHERE user_id = :uid) ");
            default -> {
            }
        }
        List<VideoDto> rows = db.jdbc().query(
                VideoSql.SELECT + where + " ORDER BY v.is_live DESC, v.published_at DESC LIMIT :limit OFFSET :offset",
                p, VideoSql.MAPPER);
        return PageResult.of(rows, paging);
    }

    private static String blank(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
