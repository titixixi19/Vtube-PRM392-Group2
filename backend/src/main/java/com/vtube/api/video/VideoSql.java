package com.vtube.api.video;

import com.vtube.api.channel.ChannelBrief;
import com.vtube.api.common.Db;
import org.springframework.jdbc.core.RowMapper;

/** Câu SELECT và RowMapper dùng chung cho mọi truy vấn trả về VideoDto. */
public final class VideoSql {
    private VideoSql() {
    }

    /** Dùng: VideoSql.SELECT + " WHERE ... ORDER BY ... LIMIT :limit OFFSET :offset" */
    public static final String SELECT = """
            SELECT v.id, v.title, v.description, v.thumbnail_url, v.video_url, v.duration_seconds,
                   v.view_count, v.like_count, v.dislike_count, v.comment_count, v.category_id,
                   v.is_short, v.is_live, v.visibility, v.comments_enabled, v.tags, v.published_at,
                   c.id AS ch_id, c.name AS ch_name, c.handle AS ch_handle, c.avatar_url AS ch_avatar,
                   c.verified AS ch_verified, c.subscriber_count AS ch_subs
            FROM videos v
            JOIN channels c ON c.id = v.channel_id
            """;

    /** Chỉ video công khai hoặc video của chính mình (:uid có thể NULL). */
    public static final String VISIBLE = " (v.visibility = 'public' OR c.user_id = :uid) ";

    public static final RowMapper<VideoDto> MAPPER = (rs, i) -> new VideoDto(
            rs.getLong("id"),
            rs.getString("title"),
            rs.getString("description"),
            rs.getString("thumbnail_url"),
            rs.getString("video_url"),
            rs.getInt("duration_seconds"),
            rs.getLong("view_count"),
            rs.getLong("like_count"),
            rs.getLong("dislike_count"),
            rs.getLong("comment_count"),
            Db.nullableInt(rs, "category_id"),
            Db.bool(rs, "is_short"),
            Db.bool(rs, "is_live"),
            rs.getString("visibility"),
            Db.bool(rs, "comments_enabled"),
            rs.getString("tags"),
            rs.getString("published_at"),
            new ChannelBrief(rs.getLong("ch_id"), rs.getString("ch_name"), rs.getString("ch_handle"),
                    rs.getString("ch_avatar"), Db.bool(rs, "ch_verified"), rs.getLong("ch_subs")),
            null);
}
