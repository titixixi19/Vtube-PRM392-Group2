package com.vtube.api.video;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import com.vtube.api.notification.NotificationService;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
public class VideoService {
    private final Db db;
    private final NotificationService notifications;

    public VideoService(Db db, NotificationService notifications) {
        this.db = db;
        this.notifications = notifications;
    }

    public record Category(int id, String name, String slug) {
    }

    public List<Category> categories() {
        return db.jdbc().query("SELECT id, name, slug FROM categories ORDER BY id", Db.params(),
                (rs, i) -> new Category(rs.getInt("id"), rs.getString("name"), rs.getString("slug")));
    }

    /**
     * Feed trang chủ. category: null/"all" = tất cả, slug danh mục (music, gaming...),
     * "live" = đang trực tiếp, "recent" = đăng trong 7 ngày.
     */
    public PageResult<VideoDto> feed(Long uid, String category, Paging paging) {
        StringBuilder where = new StringBuilder(" WHERE v.visibility = 'public' AND v.is_short = 0 ");
        MapSqlParameterSource p = Db.params().addValue("uid", uid)
                .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset());
        if ("live".equals(category)) {
            where.append(" AND v.is_live = 1 ");
        } else if ("recent".equals(category)) {
            where.append(" AND v.published_at >= strftime('%Y-%m-%dT%H:%M:%SZ','now','-7 days') ");
        } else if (category != null && !category.isBlank() && !"all".equals(category)) {
            where.append(" AND v.category_id = (SELECT id FROM categories WHERE slug = :cat) ");
            p.addValue("cat", category);
        }
        if (uid != null) {
            where.append(" AND v.id NOT IN (SELECT video_id FROM hidden_videos WHERE user_id = :uid) ");
        }
        List<VideoDto> rows = db.jdbc().query(
                VideoSql.SELECT + where + " ORDER BY v.is_live DESC, v.published_at DESC LIMIT :limit OFFSET :offset",
                p, VideoSql.MAPPER);
        return PageResult.of(rows, paging);
    }

    public PageResult<VideoDto> shorts(Long uid, Paging paging) {
        List<VideoDto> rows = db.jdbc().query(
                VideoSql.SELECT + " WHERE v.visibility = 'public' AND v.is_short = 1 "
                        + " ORDER BY v.published_at DESC LIMIT :limit OFFSET :offset",
                Db.params().addValue("uid", uid).addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset()),
                VideoSql.MAPPER);
        return PageResult.of(rows, paging);
    }

    /** Video kèm trạng thái của người xem. Video riêng tư chỉ chủ kênh xem được. */
    public VideoDto detail(Long uid, long id) {
        VideoDto v = findVisible(uid, id);
        if (uid == null) {
            return v;
        }
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("vid", id).addValue("ch", v.channel().id());
        List<Integer> reaction = db.jdbc().query(
                "SELECT value FROM video_reactions WHERE user_id = :uid AND video_id = :vid", p, (rs, i) -> rs.getInt(1));
        List<String> sub = db.jdbc().query(
                "SELECT notify_mode FROM subscriptions WHERE user_id = :uid AND channel_id = :ch", p, (rs, i) -> rs.getString(1));
        List<Integer> progress = db.jdbc().query(
                "SELECT progress_seconds FROM watch_history WHERE user_id = :uid AND video_id = :vid", p, (rs, i) -> rs.getInt(1));
        boolean watchLater = db.exists("""
                SELECT 1 FROM playlist_videos pv JOIN playlists pl ON pl.id = pv.playlist_id
                WHERE pl.user_id = :uid AND pl.kind = 'watch_later' AND pv.video_id = :vid""", p);
        boolean owner = db.exists("SELECT 1 FROM channels WHERE id = :ch AND user_id = :uid", p);
        return v.withViewer(new ViewerState(
                reaction.isEmpty() ? 0 : reaction.get(0),
                !sub.isEmpty(),
                sub.isEmpty() ? null : sub.get(0),
                progress.isEmpty() ? 0 : progress.get(0),
                watchLater,
                owner));
    }

    /** filter: all | channel (từ kênh này) | related (cùng danh mục) | recent (mới tải lên) */
    public PageResult<VideoDto> related(Long uid, long id, String filter, Paging paging) {
        VideoDto v = findVisible(uid, id);
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("id", id)
                .addValue("ch", v.channel().id()).addValue("cat", v.categoryId())
                .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset());
        String where = " WHERE v.visibility = 'public' AND v.is_short = 0 AND v.id <> :id ";
        String order;
        switch (filter == null ? "all" : filter) {
            case "channel" -> {
                where += " AND v.channel_id = :ch ";
                order = " v.published_at DESC ";
            }
            case "related" -> {
                where += " AND v.category_id = :cat ";
                order = " v.view_count DESC ";
            }
            case "recent" -> order = " v.published_at DESC ";
            default -> order = " (v.channel_id = :ch) DESC, (v.category_id = :cat) DESC, v.view_count DESC ";
        }
        List<VideoDto> rows = db.jdbc().query(
                VideoSql.SELECT + where + " ORDER BY " + order + " LIMIT :limit OFFSET :offset", p, VideoSql.MAPPER);
        return PageResult.of(rows, paging);
    }

    public void addView(long id) {
        int n = db.jdbc().update("UPDATE videos SET view_count = view_count + 1 WHERE id = :id",
                Db.params().addValue("id", id));
        if (n == 0) {
            throw ApiException.notFound("video");
        }
    }

    public record ReactionResult(long likeCount, long dislikeCount, int myReaction) {
    }

    /** value: 1 = like, -1 = dislike, 0 = bỏ. Đồng bộ playlist "Video đã thích". */
    @Transactional
    public ReactionResult react(long uid, long videoId, int value) {
        if (value < -1 || value > 1) {
            throw ApiException.badRequest("value phải là 1, -1 hoặc 0");
        }
        findVisible(uid, videoId);
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("vid", videoId).addValue("val", value);
        List<Integer> old = db.jdbc().query(
                "SELECT value FROM video_reactions WHERE user_id = :uid AND video_id = :vid", p, (rs, i) -> rs.getInt(1));
        int before = old.isEmpty() ? 0 : old.get(0);
        if (before != value) {
            db.jdbc().update("DELETE FROM video_reactions WHERE user_id = :uid AND video_id = :vid", p);
            if (value != 0) {
                db.jdbc().update("INSERT INTO video_reactions (user_id, video_id, value) VALUES (:uid, :vid, :val)", p);
            }
            int likeDelta = (value == 1 ? 1 : 0) - (before == 1 ? 1 : 0);
            int dislikeDelta = (value == -1 ? 1 : 0) - (before == -1 ? 1 : 0);
            db.jdbc().update("""
                            UPDATE videos SET like_count = MAX(0, like_count + :ld),
                                              dislike_count = MAX(0, dislike_count + :dd)
                            WHERE id = :vid""",
                    p.addValue("ld", likeDelta).addValue("dd", dislikeDelta));
            syncLikedPlaylist(uid, videoId, value == 1);
        }
        Map<String, Object> counts = db.jdbc().queryForMap(
                "SELECT like_count, dislike_count FROM videos WHERE id = :vid", p);
        return new ReactionResult(((Number) counts.get("like_count")).longValue(),
                ((Number) counts.get("dislike_count")).longValue(), value);
    }

    private void syncLikedPlaylist(long uid, long videoId, boolean liked) {
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("vid", videoId);
        if (liked) {
            db.jdbc().update("""
                    INSERT OR IGNORE INTO playlist_videos (playlist_id, video_id, position)
                    SELECT pl.id, :vid,
                           COALESCE((SELECT MAX(position) + 1 FROM playlist_videos WHERE playlist_id = pl.id), 0)
                    FROM playlists pl WHERE pl.user_id = :uid AND pl.kind = 'liked'""", p);
        } else {
            db.jdbc().update("""
                    DELETE FROM playlist_videos WHERE video_id = :vid
                    AND playlist_id IN (SELECT id FROM playlists WHERE user_id = :uid AND kind = 'liked')""", p);
        }
    }

    public void hide(long uid, long videoId) {
        db.jdbc().update("INSERT OR IGNORE INTO hidden_videos (user_id, video_id) VALUES (:uid, :vid)",
                Db.params().addValue("uid", uid).addValue("vid", videoId));
    }

    public record SaveVideoRequest(String title, String description, String thumbnailUrl, String videoUrl,
                                   Integer durationSeconds, Integer categoryId, Boolean shortVideo,
                                   String visibility, Boolean commentsEnabled, Boolean madeForKids, String tags) {
    }

    /** Tạo video sau khi đã upload file qua /api/uploads. Gửi thông báo cho người đăng ký kênh. */
    @Transactional
    public VideoDto create(long uid, SaveVideoRequest req) {
        if (req.title() == null || req.title().isBlank()) {
            throw ApiException.badRequest("Tiêu đề không được để trống");
        }
        if (req.videoUrl() == null || req.videoUrl().isBlank()) {
            throw ApiException.badRequest("Thiếu videoUrl (hãy upload file trước)");
        }
        long channelId = myChannelId(uid);
        String visibility = normalizeVisibility(req.visibility());
        boolean isShort = Boolean.TRUE.equals(req.shortVideo());
        long id = db.insert("""
                        INSERT INTO videos (channel_id, title, description, thumbnail_url, video_url, duration_seconds,
                                            category_id, is_short, visibility, comments_enabled, made_for_kids, tags)
                        VALUES (:ch, :title, :desc, :thumb, :url, :dur, :cat, :short, :vis, :cmt, :kids, :tags)""",
                Db.params().addValue("ch", channelId).addValue("title", req.title().trim())
                        .addValue("desc", req.description()).addValue("thumb", req.thumbnailUrl())
                        .addValue("url", req.videoUrl()).addValue("dur", req.durationSeconds() == null ? 0 : req.durationSeconds())
                        .addValue("cat", req.categoryId()).addValue("short", isShort ? 1 : 0).addValue("vis", visibility)
                        .addValue("cmt", Boolean.FALSE.equals(req.commentsEnabled()) ? 0 : 1)
                        .addValue("kids", Boolean.TRUE.equals(req.madeForKids()) ? 1 : 0)
                        .addValue("tags", req.tags()));
        if ("public".equals(visibility)) {
            String channelName = db.jdbc().queryForObject("SELECT name FROM channels WHERE id = :ch",
                    Db.params().addValue("ch", channelId), String.class);
            notifications.notifySubscribers(channelId, isShort ? "new_short" : "new_video", id,
                    isShort ? channelName + " đã đăng một Short mới"
                            : channelName + " đã tải lên: " + req.title().trim());
        }
        return detail(uid, id);
    }

    /** Sửa video của mình. Trường nào null thì giữ nguyên. */
    public VideoDto update(long uid, long id, SaveVideoRequest req) {
        requireOwner(uid, id);
        db.jdbc().update("""
                        UPDATE videos SET
                            title = COALESCE(:title, title),
                            description = COALESCE(:desc, description),
                            thumbnail_url = COALESCE(:thumb, thumbnail_url),
                            category_id = COALESCE(:cat, category_id),
                            visibility = COALESCE(:vis, visibility),
                            comments_enabled = COALESCE(:cmt, comments_enabled),
                            made_for_kids = COALESCE(:kids, made_for_kids),
                            tags = COALESCE(:tags, tags)
                        WHERE id = :id""",
                Db.params().addValue("id", id).addValue("title", req.title()).addValue("desc", req.description())
                        .addValue("thumb", req.thumbnailUrl()).addValue("cat", req.categoryId())
                        .addValue("vis", req.visibility() == null ? null : normalizeVisibility(req.visibility()))
                        .addValue("cmt", req.commentsEnabled() == null ? null : (req.commentsEnabled() ? 1 : 0))
                        .addValue("kids", req.madeForKids() == null ? null : (req.madeForKids() ? 1 : 0))
                        .addValue("tags", req.tags()));
        return detail(uid, id);
    }

    public void delete(long uid, long id) {
        requireOwner(uid, id);
        db.jdbc().update("DELETE FROM videos WHERE id = :id", Db.params().addValue("id", id));
    }

    // ------------------------------------------------------------------

    public VideoDto findVisible(Long uid, long id) {
        List<VideoDto> rows = db.jdbc().query(VideoSql.SELECT + " WHERE v.id = :id AND " + VideoSql.VISIBLE,
                Db.params().addValue("id", id).addValue("uid", uid), VideoSql.MAPPER);
        if (rows.isEmpty()) {
            throw ApiException.notFound("video");
        }
        return rows.get(0);
    }

    private void requireOwner(long uid, long videoId) {
        boolean owner = db.exists("""
                        SELECT 1 FROM videos v JOIN channels c ON c.id = v.channel_id
                        WHERE v.id = :id AND c.user_id = :uid""",
                Db.params().addValue("id", videoId).addValue("uid", uid));
        if (!owner) {
            if (!db.exists("SELECT 1 FROM videos WHERE id = :id", Db.params().addValue("id", videoId))) {
                throw ApiException.notFound("video");
            }
            throw ApiException.forbidden();
        }
    }

    private long myChannelId(long uid) {
        return db.count("SELECT id FROM channels WHERE user_id = :uid", Db.params().addValue("uid", uid));
    }

    private static String normalizeVisibility(String v) {
        if (v == null || v.isBlank()) {
            return "public";
        }
        if (!List.of("public", "unlisted", "private").contains(v)) {
            throw ApiException.badRequest("visibility phải là public, unlisted hoặc private");
        }
        return v;
    }
}
