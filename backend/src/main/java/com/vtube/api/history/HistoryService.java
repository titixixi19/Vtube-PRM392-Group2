package com.vtube.api.history;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import com.vtube.api.common.Times;
import com.vtube.api.user.UserService;
import com.vtube.api.video.VideoDto;
import com.vtube.api.video.VideoSql;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class HistoryService {
    private final Db db;
    private final UserService users;

    public HistoryService(Db db, UserService users) {
        this.db = db;
        this.users = users;
    }

    /** Một mục lịch sử. App tự nhóm theo ngày dựa vào watchedAt. */
    public record HistoryItem(String watchedAt, int progressSeconds, VideoDto video) {
    }

    /** type: all | video | short | music.  q: lọc theo tiêu đề video hoặc tên kênh. */
    public PageResult<HistoryItem> list(long uid, String type, String q, Paging paging) {
        StringBuilder where = new StringBuilder(" WHERE h.user_id = :uid AND " + VideoSql.VISIBLE);
        MapSqlParameterSource p = Db.params().addValue("uid", uid)
                .addValue("limit", paging.limitPlusOne()).addValue("offset", paging.offset());
        switch (type == null ? "all" : type) {
            case "video" -> where.append(" AND v.is_short = 0 ");
            case "short" -> where.append(" AND v.is_short = 1 ");
            case "music" -> where.append(" AND v.category_id = (SELECT id FROM categories WHERE slug = 'music') ");
            default -> {
            }
        }
        if (q != null && !q.isBlank()) {
            where.append(" AND (v.title LIKE :q OR c.name LIKE :q) ");
            p.addValue("q", "%" + q.trim() + "%");
        }
        String sql = VideoSql.SELECT.replace("SELECT v.id,", "SELECT h.watched_at, h.progress_seconds, v.id,")
                + " JOIN watch_history h ON h.video_id = v.id " + where
                + " ORDER BY h.watched_at DESC LIMIT :limit OFFSET :offset";
        List<HistoryItem> rows = db.jdbc().query(sql, p, (rs, i) -> new HistoryItem(
                rs.getString("watched_at"), rs.getInt("progress_seconds"), VideoSql.MAPPER.mapRow(rs, i)));
        return PageResult.of(rows, paging);
    }

    public record SaveResult(boolean saved) {
    }

    /** Lưu / cập nhật vị trí đang xem. Không lưu nếu user đang tạm dừng lịch sử. */
    public SaveResult save(long uid, long videoId, int progressSeconds) {
        if (users.isHistoryPaused(uid)) {
            return new SaveResult(false);
        }
        if (!db.exists("SELECT 1 FROM videos WHERE id = :vid", Db.params().addValue("vid", videoId))) {
            throw ApiException.notFound("video");
        }
        db.jdbc().update("""
                        INSERT INTO watch_history (user_id, video_id, progress_seconds, watched_at)
                        VALUES (:uid, :vid, :p, :now)
                        ON CONFLICT (user_id, video_id)
                        DO UPDATE SET progress_seconds = excluded.progress_seconds, watched_at = excluded.watched_at""",
                Db.params().addValue("uid", uid).addValue("vid", videoId)
                        .addValue("p", Math.max(0, progressSeconds)).addValue("now", Times.now()));
        return new SaveResult(true);
    }

    public void delete(long uid, long videoId) {
        db.jdbc().update("DELETE FROM watch_history WHERE user_id = :uid AND video_id = :vid",
                Db.params().addValue("uid", uid).addValue("vid", videoId));
    }

    public void clear(long uid) {
        db.jdbc().update("DELETE FROM watch_history WHERE user_id = :uid", Db.params().addValue("uid", uid));
    }
}
