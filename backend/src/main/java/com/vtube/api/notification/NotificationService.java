package com.vtube.api.notification;

import com.vtube.api.channel.ChannelBrief;
import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class NotificationService {
    private final Db db;

    public NotificationService(Db db) {
        this.db = db;
    }

    private static final String SELECT = """
            SELECT n.id, n.type, n.message, n.is_read, n.created_at, n.video_id, n.comment_id,
                   c.id AS ch_id, c.name AS ch_name, c.handle AS ch_handle, c.avatar_url AS ch_avatar,
                   c.verified AS ch_verified, c.subscriber_count AS ch_subs,
                   v.thumbnail_url AS v_thumb, v.duration_seconds AS v_dur, v.is_short AS v_short
            FROM notifications n
            LEFT JOIN channels c ON c.id = n.actor_channel_id
            LEFT JOIN videos v ON v.id = n.video_id
            """;

    private static final RowMapper<NotificationDto> MAPPER = (rs, i) -> {
        Long chId = Db.nullableLong(rs, "ch_id");
        ChannelBrief actor = chId == null ? null : new ChannelBrief(chId, rs.getString("ch_name"),
                rs.getString("ch_handle"), rs.getString("ch_avatar"), Db.bool(rs, "ch_verified"), rs.getLong("ch_subs"));
        Long videoId = Db.nullableLong(rs, "video_id");
        return new NotificationDto(
                rs.getLong("id"), rs.getString("type"), rs.getString("message"), Db.bool(rs, "is_read"),
                rs.getString("created_at"), actor, videoId,
                videoId == null ? null : rs.getString("v_thumb"),
                videoId == null ? null : rs.getInt("v_dur"),
                videoId == null ? null : Db.bool(rs, "v_short"),
                Db.nullableLong(rs, "comment_id"));
    };

    /** type = all | mention (mention = trả lời / thả tim bình luận) */
    public PageResult<NotificationDto> list(long uid, String type, Paging paging) {
        String filter = "mention".equals(type) ? " AND n.type IN ('comment_reply','comment_heart') " : "";
        List<NotificationDto> rows = db.jdbc().query(
                SELECT + " WHERE n.user_id = :uid" + filter + " ORDER BY n.created_at DESC, n.id DESC LIMIT :limit OFFSET :offset",
                Db.params().addValue("uid", uid).addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset()),
                MAPPER);
        return PageResult.of(rows, paging);
    }

    public long unreadCount(long uid) {
        return db.count("SELECT COUNT(*) FROM notifications WHERE user_id = :uid AND is_read = 0",
                Db.params().addValue("uid", uid));
    }

    public void markRead(long uid, long id) {
        int n = db.jdbc().update("UPDATE notifications SET is_read = 1 WHERE id = :id AND user_id = :uid",
                Db.params().addValue("id", id).addValue("uid", uid));
        if (n == 0) {
            throw ApiException.notFound("thông báo");
        }
    }

    public void markAllRead(long uid) {
        db.jdbc().update("UPDATE notifications SET is_read = 1 WHERE user_id = :uid", Db.params().addValue("uid", uid));
    }

    public void delete(long uid, long id) {
        int n = db.jdbc().update("DELETE FROM notifications WHERE id = :id AND user_id = :uid",
                Db.params().addValue("id", id).addValue("uid", uid));
        if (n == 0) {
            throw ApiException.notFound("thông báo");
        }
    }

    // ------------------------------------------------------------------
    // Các hàm tạo thông báo, được service khác gọi khi có sự kiện
    // ------------------------------------------------------------------

    /** Gửi cho 1 người. Bỏ qua nếu người nhận chính là người gây ra sự kiện. */
    public void notifyUser(long toUserId, String type, Long actorChannelId, Long videoId, Long commentId, String message) {
        if (actorChannelId != null) {
            Long actorUser = ownerOfChannel(actorChannelId);
            if (actorUser != null && actorUser == toUserId) {
                return;
            }
        }
        db.jdbc().update("""
                        INSERT INTO notifications (user_id, type, actor_channel_id, video_id, comment_id, message)
                        VALUES (:to, :type, :actor, :video, :comment, :msg)""",
                new MapSqlParameterSource().addValue("to", toUserId).addValue("type", type)
                        .addValue("actor", actorChannelId).addValue("video", videoId)
                        .addValue("comment", commentId).addValue("msg", message));
    }

    /** Gửi cho mọi người đăng ký kênh (trừ người chọn "không nhận"). */
    public void notifySubscribers(long channelId, String type, long videoId, String message) {
        db.jdbc().update("""
                        INSERT INTO notifications (user_id, type, actor_channel_id, video_id, message)
                        SELECT s.user_id, :type, :ch, :video, :msg
                        FROM subscriptions s
                        WHERE s.channel_id = :ch AND s.notify_mode <> 'none'""",
                Db.params().addValue("type", type).addValue("ch", channelId).addValue("video", videoId)
                        .addValue("msg", message));
    }

    private Long ownerOfChannel(long channelId) {
        List<Long> ids = db.jdbc().query("SELECT user_id FROM channels WHERE id = :id",
                Db.params().addValue("id", channelId), (rs, i) -> rs.getLong(1));
        return ids.isEmpty() ? null : ids.get(0);
    }
}
