package com.vtube.api.playlist;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.Times;
import com.vtube.api.video.VideoDto;
import com.vtube.api.video.VideoSql;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
public class PlaylistService {
    private final Db db;

    public PlaylistService(Db db) {
        this.db = db;
    }

    private static final String SELECT = """
            SELECT p.id, p.title, p.description, p.visibility, p.kind, p.updated_at, p.user_id,
                   u.display_name AS owner_name, c.id AS owner_channel,
                   (SELECT COUNT(*) FROM playlist_videos pv WHERE pv.playlist_id = p.id) AS video_count,
                   (SELECT v.thumbnail_url FROM playlist_videos pv JOIN videos v ON v.id = pv.video_id
                     WHERE pv.playlist_id = p.id ORDER BY pv.position LIMIT 1) AS thumb,
                   CASE WHEN :vid IS NULL THEN NULL
                        ELSE EXISTS (SELECT 1 FROM playlist_videos pv WHERE pv.playlist_id = p.id AND pv.video_id = :vid)
                   END AS contains
            FROM playlists p
            JOIN users u ON u.id = p.user_id
            JOIN channels c ON c.user_id = p.user_id
            """;

    private static final RowMapper<PlaylistDto> MAPPER = (rs, i) -> {
        Integer contains = Db.nullableInt(rs, "contains");
        return new PlaylistDto(rs.getLong("id"), rs.getString("title"), rs.getString("description"),
                rs.getString("visibility"), rs.getString("kind"), rs.getLong("video_count"), rs.getString("thumb"),
                rs.getString("updated_at"), rs.getLong("user_id"), rs.getString("owner_name"),
                rs.getLong("owner_channel"), contains == null ? null : contains != 0);
    };

    /** Playlist của mình: Video đã thích, Xem sau, rồi các playlist tự tạo (mới sửa trước). */
    public List<PlaylistDto> mine(long uid, Long videoId) {
        return db.jdbc().query(SELECT + """
                         WHERE p.user_id = :uid
                         ORDER BY CASE p.kind WHEN 'liked' THEN 0 WHEN 'watch_later' THEN 1 ELSE 2 END, p.updated_at DESC""",
                Db.params().addValue("uid", uid).addValue("vid", videoId), MAPPER);
    }

    /** Playlist công khai của 1 kênh (tab "Danh sách phát" ở màn 11). Chủ kênh thấy cả playlist riêng tư. */
    public List<PlaylistDto> ofChannel(Long uid, long channelId) {
        return db.jdbc().query(SELECT + """
                         WHERE c.id = :ch AND p.kind = 'custom' AND (p.visibility = 'public' OR p.user_id = :uid)
                         ORDER BY p.updated_at DESC""",
                Db.params().addValue("ch", channelId).addValue("uid", uid).addValue("vid", null), MAPPER);
    }

    /** Dùng cho tìm kiếm: playlist công khai có tên khớp. */
    public List<PlaylistDto> search(String like, int limit, int offset) {
        return db.jdbc().query(SELECT + """
                         WHERE p.kind = 'custom' AND p.visibility = 'public' AND p.title LIKE :like
                         ORDER BY p.updated_at DESC LIMIT :limit OFFSET :offset""",
                Db.params().addValue("like", like).addValue("vid", null).addValue("limit", limit).addValue("offset", offset),
                MAPPER);
    }

    /** sort: manual | added_new | added_old | popular | published */
    public PlaylistDetailDto detail(Long uid, long id, String sort) {
        PlaylistDto pl = find(uid, id);
        boolean mine = uid != null && pl.ownerUserId() == uid;
        String order = switch (sort == null ? "manual" : sort) {
            case "added_new" -> "pv.added_at DESC";
            case "added_old" -> "pv.added_at ASC";
            case "popular" -> "v.view_count DESC";
            case "published" -> "v.published_at DESC";
            default -> "pv.position ASC";
        };
        RowMapper<PlaylistDetailDto.Item> itemMapper = (rs, i) -> new PlaylistDetailDto.Item(
                rs.getInt("position"), rs.getString("added_at"), VideoSql.MAPPER.mapRow(rs, i));
        List<PlaylistDetailDto.Item> items = db.jdbc().query(
                VideoSql.SELECT.replace("SELECT v.id,", "SELECT pv.position, pv.added_at, v.id,")
                        + " JOIN playlist_videos pv ON pv.video_id = v.id "
                        + " WHERE pv.playlist_id = :pid AND " + VideoSql.VISIBLE + " ORDER BY " + order,
                Db.params().addValue("pid", id).addValue("uid", uid), itemMapper);
        long views = items.stream().mapToLong(it -> it.video().viewCount()).sum();
        return new PlaylistDetailDto(pl, mine, views, items);
    }

    @Transactional
    public PlaylistDto create(long uid, String title, String description, String visibility) {
        String t = requireTitle(title);
        long id = db.insert("""
                        INSERT INTO playlists (user_id, title, description, visibility, kind)
                        VALUES (:uid, :title, :desc, :vis, 'custom')""",
                Db.params().addValue("uid", uid).addValue("title", t).addValue("desc", description)
                        .addValue("vis", normalizeVisibility(visibility)));
        return find(uid, id);
    }

    /** Video đã thích và Xem sau không được đổi tên. */
    public PlaylistDto update(long uid, long id, String title, String description, String visibility) {
        PlaylistDto pl = requireMine(uid, id);
        if (!"custom".equals(pl.kind()) && title != null && !title.equals(pl.title())) {
            throw ApiException.badRequest("Không thể đổi tên danh sách phát hệ thống");
        }
        db.jdbc().update("""
                        UPDATE playlists SET title = COALESCE(:title, title), description = COALESCE(:desc, description),
                               visibility = COALESCE(:vis, visibility), updated_at = :now
                        WHERE id = :id""",
                Db.params().addValue("title", title == null ? null : requireTitle(title)).addValue("desc", description)
                        .addValue("vis", visibility == null ? null : normalizeVisibility(visibility))
                        .addValue("now", Times.now()).addValue("id", id));
        return find(uid, id);
    }

    public void delete(long uid, long id) {
        PlaylistDto pl = requireMine(uid, id);
        if (!"custom".equals(pl.kind())) {
            throw ApiException.badRequest("Không thể xóa danh sách phát hệ thống");
        }
        db.jdbc().update("DELETE FROM playlists WHERE id = :id", Db.params().addValue("id", id));
    }

    @Transactional
    public PlaylistDto addVideo(long uid, long id, long videoId) {
        requireMine(uid, id);
        if (!db.exists("SELECT 1 FROM videos WHERE id = :vid", Db.params().addValue("vid", videoId))) {
            throw ApiException.notFound("video");
        }
        MapSqlParameterSource p = Db.params().addValue("pid", id).addValue("vid", videoId).addValue("now", Times.now());
        db.jdbc().update("""
                INSERT OR IGNORE INTO playlist_videos (playlist_id, video_id, position)
                VALUES (:pid, :vid, COALESCE((SELECT MAX(position) + 1 FROM playlist_videos WHERE playlist_id = :pid), 0))""", p);
        db.jdbc().update("UPDATE playlists SET updated_at = :now WHERE id = :pid", p);
        return find(uid, id);
    }

    @Transactional
    public PlaylistDto removeVideo(long uid, long id, long videoId) {
        PlaylistDto pl = requireMine(uid, id);
        MapSqlParameterSource p = Db.params().addValue("pid", id).addValue("vid", videoId).addValue("now", Times.now())
                .addValue("uid", uid);
        db.jdbc().update("DELETE FROM playlist_videos WHERE playlist_id = :pid AND video_id = :vid", p);
        db.jdbc().update("UPDATE playlists SET updated_at = :now WHERE id = :pid", p);
        if ("liked".equals(pl.kind())) {
            // Bỏ khỏi "Video đã thích" = bỏ like
            int n = db.jdbc().update("DELETE FROM video_reactions WHERE user_id = :uid AND video_id = :vid AND value = 1", p);
            if (n > 0) {
                db.jdbc().update("UPDATE videos SET like_count = MAX(0, like_count - 1) WHERE id = :vid", p);
            }
        }
        return find(uid, id);
    }

    /** videoIds theo thứ tự mới (sau khi kéo thả). */
    @Transactional
    public PlaylistDto reorder(long uid, long id, List<Long> videoIds) {
        requireMine(uid, id);
        for (int i = 0; i < videoIds.size(); i++) {
            db.jdbc().update("UPDATE playlist_videos SET position = :pos WHERE playlist_id = :pid AND video_id = :vid",
                    Db.params().addValue("pos", i).addValue("pid", id).addValue("vid", videoIds.get(i)));
        }
        db.jdbc().update("UPDATE playlists SET updated_at = :now WHERE id = :pid",
                Db.params().addValue("now", Times.now()).addValue("pid", id));
        return find(uid, id);
    }

    /** Lối tắt cho nút "Lưu vào Xem sau". */
    public PlaylistDto setWatchLater(long uid, long videoId, boolean add) {
        long id = systemPlaylistId(uid, "watch_later");
        return add ? addVideo(uid, id, videoId) : removeVideo(uid, id, videoId);
    }

    // ------------------------------------------------------------------

    private long systemPlaylistId(long uid, String kind) {
        List<Long> ids = db.jdbc().query("SELECT id FROM playlists WHERE user_id = :uid AND kind = :kind",
                Db.params().addValue("uid", uid).addValue("kind", kind), (rs, i) -> rs.getLong(1));
        if (!ids.isEmpty()) {
            return ids.get(0);
        }
        db.jdbc().update("INSERT INTO playlists (user_id, title, visibility, kind) VALUES (:uid, :title, 'private', :kind)",
                Db.params().addValue("uid", uid).addValue("kind", kind)
                        .addValue("title", "liked".equals(kind) ? "Video đã thích" : "Xem sau"));
        return systemPlaylistId(uid, kind);
    }

    private PlaylistDto find(Long uid, long id) {
        List<PlaylistDto> rows = db.jdbc().query(SELECT + " WHERE p.id = :id",
                Db.params().addValue("id", id).addValue("vid", null), MAPPER);
        if (rows.isEmpty()) {
            throw ApiException.notFound("danh sách phát");
        }
        PlaylistDto pl = rows.get(0);
        boolean mine = uid != null && pl.ownerUserId() == uid;
        if ("private".equals(pl.visibility()) && !mine) {
            throw new ApiException(HttpStatus.FORBIDDEN, "Danh sách phát này là riêng tư");
        }
        return pl;
    }

    private PlaylistDto requireMine(long uid, long id) {
        PlaylistDto pl = find(uid, id);
        if (pl.ownerUserId() != uid) {
            throw ApiException.forbidden();
        }
        return pl;
    }

    private static String requireTitle(String title) {
        if (title == null || title.isBlank()) {
            throw ApiException.badRequest("Tên danh sách phát không được để trống");
        }
        if (title.trim().length() > 150) {
            throw ApiException.badRequest("Tên danh sách phát tối đa 150 ký tự");
        }
        return title.trim();
    }

    private static String normalizeVisibility(String v) {
        if (v == null || v.isBlank()) {
            return "private";
        }
        if (!List.of("public", "unlisted", "private").contains(v)) {
            throw ApiException.badRequest("visibility phải là public, unlisted hoặc private");
        }
        return v;
    }
}
