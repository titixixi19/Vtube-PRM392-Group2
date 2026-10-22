package com.vtube.api.comment;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import com.vtube.api.common.Times;
import com.vtube.api.notification.NotificationService;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Map;

@Service
public class CommentService {
    private final Db db;
    private final NotificationService notifications;

    public CommentService(Db db, NotificationService notifications) {
        this.db = db;
        this.notifications = notifications;
    }

    private static final String SELECT = """
            SELECT cm.id, cm.video_id, cm.parent_id, cm.content, cm.like_count, cm.reply_count, cm.is_pinned,
                   cm.is_hearted, cm.created_at, cm.updated_at,
                   cm.user_id, ch.id AS ch_id, ch.name AS ch_name, ch.handle AS ch_handle, ch.avatar_url AS ch_avatar,
                   (vc.user_id = cm.user_id) AS by_owner,
                   COALESCE((SELECT value FROM comment_reactions r WHERE r.comment_id = cm.id AND r.user_id = :uid), 0) AS my_reaction
            FROM comments cm
            JOIN channels ch ON ch.user_id = cm.user_id
            JOIN videos v ON v.id = cm.video_id
            JOIN channels vc ON vc.id = v.channel_id
            """;

    private static final RowMapper<CommentDto> MAPPER = (rs, i) -> new CommentDto(
            rs.getLong("id"), rs.getLong("video_id"), Db.nullableLong(rs, "parent_id"), rs.getString("content"),
            rs.getLong("like_count"), rs.getLong("reply_count"), Db.bool(rs, "is_pinned"), Db.bool(rs, "is_hearted"),
            rs.getString("created_at"), rs.getString("updated_at"),
            new CommentDto.Author(rs.getLong("user_id"), rs.getLong("ch_id"), rs.getString("ch_name"),
                    rs.getString("ch_handle"), rs.getString("ch_avatar")),
            Db.bool(rs, "by_owner"), rs.getInt("my_reaction"));

    /** sort: top (nhiều like) | new (mới nhất). Bình luận ghim luôn đứng đầu. */
    public PageResult<CommentDto> list(Long uid, long videoId, String sort, Paging paging) {
        requireVideo(videoId);
        String order = "new".equals(sort) ? "cm.created_at DESC" : "cm.like_count DESC, cm.created_at DESC";
        List<CommentDto> rows = db.jdbc().query(
                SELECT + " WHERE cm.video_id = :vid AND cm.parent_id IS NULL ORDER BY cm.is_pinned DESC, " + order
                        + " LIMIT :limit OFFSET :offset",
                Db.params().addValue("uid", uid).addValue("vid", videoId)
                        .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset()),
                MAPPER);
        return PageResult.of(rows, paging);
    }

    public PageResult<CommentDto> replies(Long uid, long commentId, Paging paging) {
        List<CommentDto> rows = db.jdbc().query(
                SELECT + " WHERE cm.parent_id = :pid ORDER BY cm.created_at ASC LIMIT :limit OFFSET :offset",
                Db.params().addValue("uid", uid).addValue("pid", commentId)
                        .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset()),
                MAPPER);
        return PageResult.of(rows, paging);
    }

    /** Trả lời một phản hồi sẽ được gắn vào bình luận gốc (giống YouTube: chỉ 2 cấp). */
    @Transactional
    public CommentDto create(long uid, long videoId, String content, Long parentId) {
        String text = content == null ? "" : content.trim();
        if (text.isEmpty()) {
            throw ApiException.badRequest("Nội dung bình luận không được để trống");
        }
        if (text.length() > 500) {
            throw ApiException.badRequest("Bình luận tối đa 500 ký tự");
        }
        Map<String, Object> video = requireVideo(videoId);
        if (((Number) video.get("comments_enabled")).intValue() == 0) {
            throw ApiException.badRequest("Bình luận đã bị tắt cho video này");
        }
        Long rootId = null;
        Long parentAuthor = null;
        if (parentId != null) {
            List<Map<String, Object>> parent = db.jdbc().queryForList(
                    "SELECT id, parent_id, user_id, video_id FROM comments WHERE id = :id", Db.params().addValue("id", parentId));
            if (parent.isEmpty() || ((Number) parent.get(0).get("video_id")).longValue() != videoId) {
                throw ApiException.notFound("bình luận cha");
            }
            Object grand = parent.get(0).get("parent_id");
            rootId = grand == null ? parentId : ((Number) grand).longValue();
            parentAuthor = ((Number) parent.get(0).get("user_id")).longValue();
        }
        long id = db.insert("""
                        INSERT INTO comments (video_id, user_id, parent_id, content)
                        VALUES (:vid, :uid, :pid, :content)""",
                Db.params().addValue("vid", videoId).addValue("uid", uid).addValue("pid", rootId).addValue("content", text));
        db.jdbc().update("UPDATE videos SET comment_count = comment_count + 1 WHERE id = :vid",
                Db.params().addValue("vid", videoId));
        if (rootId != null) {
            db.jdbc().update("UPDATE comments SET reply_count = reply_count + 1 WHERE id = :id",
                    Db.params().addValue("id", rootId));
            Map<String, Object> me = db.jdbc().queryForMap("SELECT id, handle FROM channels WHERE user_id = :uid",
                    Db.params().addValue("uid", uid));
            String preview = text.length() > 60 ? text.substring(0, 60) + "..." : text;
            notifications.notifyUser(parentAuthor, "comment_reply", ((Number) me.get("id")).longValue(), videoId, id,
                    "@" + me.get("handle") + " đã trả lời bình luận của bạn: \"" + preview + "\"");
        }
        return get(uid, id);
    }

    public CommentDto update(long uid, long id, String content) {
        String text = content == null ? "" : content.trim();
        if (text.isEmpty() || text.length() > 500) {
            throw ApiException.badRequest("Nội dung bình luận phải từ 1 đến 500 ký tự");
        }
        int n = db.jdbc().update("UPDATE comments SET content = :c, updated_at = :now WHERE id = :id AND user_id = :uid",
                Db.params().addValue("c", text).addValue("now", Times.now()).addValue("id", id).addValue("uid", uid));
        if (n == 0) {
            throw ApiException.forbidden();
        }
        return get(uid, id);
    }

    /** Người viết hoặc chủ kênh của video được xóa. Xóa bình luận gốc sẽ xóa luôn các phản hồi. */
    @Transactional
    public void delete(long uid, long id) {
        Map<String, Object> c = requireComment(id);
        long author = ((Number) c.get("user_id")).longValue();
        long videoId = ((Number) c.get("video_id")).longValue();
        if (author != uid && !isVideoOwner(uid, videoId)) {
            throw ApiException.forbidden();
        }
        Object parent = c.get("parent_id");
        long removed = 1 + (parent == null ? ((Number) c.get("reply_count")).longValue() : 0);
        db.jdbc().update("DELETE FROM comments WHERE id = :id", Db.params().addValue("id", id));
        db.jdbc().update("UPDATE videos SET comment_count = MAX(0, comment_count - :n) WHERE id = :vid",
                Db.params().addValue("n", removed).addValue("vid", videoId));
        if (parent != null) {
            db.jdbc().update("UPDATE comments SET reply_count = MAX(0, reply_count - 1) WHERE id = :pid",
                    Db.params().addValue("pid", ((Number) parent).longValue()));
        }
    }

    @Transactional
    public CommentDto react(long uid, long id, int value) {
        if (value < -1 || value > 1) {
            throw ApiException.badRequest("value phải là 1, -1 hoặc 0");
        }
        requireComment(id);
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("cid", id).addValue("val", value);
        List<Integer> old = db.jdbc().query(
                "SELECT value FROM comment_reactions WHERE user_id = :uid AND comment_id = :cid", p, (rs, i) -> rs.getInt(1));
        int before = old.isEmpty() ? 0 : old.get(0);
        if (before != value) {
            db.jdbc().update("DELETE FROM comment_reactions WHERE user_id = :uid AND comment_id = :cid", p);
            if (value != 0) {
                db.jdbc().update("INSERT INTO comment_reactions (user_id, comment_id, value) VALUES (:uid, :cid, :val)", p);
            }
            int delta = (value == 1 ? 1 : 0) - (before == 1 ? 1 : 0);
            db.jdbc().update("UPDATE comments SET like_count = MAX(0, like_count + :d) WHERE id = :cid", p.addValue("d", delta));
        }
        return get(uid, id);
    }

    /** Chủ kênh ghim / bỏ ghim (mỗi video chỉ 1 bình luận được ghim). */
    @Transactional
    public CommentDto togglePin(long uid, long id) {
        Map<String, Object> c = requireComment(id);
        long videoId = ((Number) c.get("video_id")).longValue();
        if (!isVideoOwner(uid, videoId)) {
            throw ApiException.forbidden();
        }
        if (c.get("parent_id") != null) {
            throw ApiException.badRequest("Chỉ ghim được bình luận gốc");
        }
        boolean pinned = ((Number) c.get("is_pinned")).intValue() == 1;
        db.jdbc().update("UPDATE comments SET is_pinned = 0 WHERE video_id = :vid", Db.params().addValue("vid", videoId));
        if (!pinned) {
            db.jdbc().update("UPDATE comments SET is_pinned = 1 WHERE id = :id", Db.params().addValue("id", id));
        }
        return get(uid, id);
    }

    /** Chủ kênh thả tim / bỏ tim. Thả tim gửi thông báo cho người viết. */
    @Transactional
    public CommentDto toggleHeart(long uid, long id) {
        Map<String, Object> c = requireComment(id);
        long videoId = ((Number) c.get("video_id")).longValue();
        if (!isVideoOwner(uid, videoId)) {
            throw ApiException.forbidden();
        }
        boolean hearted = ((Number) c.get("is_hearted")).intValue() == 1;
        db.jdbc().update("UPDATE comments SET is_hearted = :h WHERE id = :id",
                Db.params().addValue("h", hearted ? 0 : 1).addValue("id", id));
        if (!hearted) {
            Map<String, Object> ch = db.jdbc().queryForMap(
                    "SELECT c.id, c.name FROM videos v JOIN channels c ON c.id = v.channel_id WHERE v.id = :vid",
                    Db.params().addValue("vid", videoId));
            notifications.notifyUser(((Number) c.get("user_id")).longValue(), "comment_heart",
                    ((Number) ch.get("id")).longValue(), videoId, id, ch.get("name") + " đã thả tim bình luận của bạn");
        }
        return get(uid, id);
    }

    // ------------------------------------------------------------------

    private CommentDto get(Long uid, long id) {
        List<CommentDto> rows = db.jdbc().query(SELECT + " WHERE cm.id = :id",
                Db.params().addValue("uid", uid).addValue("id", id), MAPPER);
        if (rows.isEmpty()) {
            throw ApiException.notFound("bình luận");
        }
        return rows.get(0);
    }

    private Map<String, Object> requireComment(long id) {
        List<Map<String, Object>> rows = db.jdbc().queryForList(
                "SELECT id, video_id, user_id, parent_id, reply_count, is_pinned, is_hearted FROM comments WHERE id = :id",
                Db.params().addValue("id", id));
        if (rows.isEmpty()) {
            throw ApiException.notFound("bình luận");
        }
        return rows.get(0);
    }

    private Map<String, Object> requireVideo(long videoId) {
        List<Map<String, Object>> rows = db.jdbc().queryForList(
                "SELECT id, comments_enabled FROM videos WHERE id = :id", Db.params().addValue("id", videoId));
        if (rows.isEmpty()) {
            throw ApiException.notFound("video");
        }
        return rows.get(0);
    }

    private boolean isVideoOwner(long uid, long videoId) {
        return db.exists("""
                        SELECT 1 FROM videos v JOIN channels c ON c.id = v.channel_id
                        WHERE v.id = :vid AND c.user_id = :uid""",
                Db.params().addValue("vid", videoId).addValue("uid", uid));
    }
}
