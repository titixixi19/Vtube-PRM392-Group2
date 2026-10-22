package com.vtube.api.search;

import com.vtube.api.channel.ChannelDto;
import com.vtube.api.channel.ChannelService;
import com.vtube.api.common.Db;
import com.vtube.api.common.Paging;
import com.vtube.api.common.Times;
import com.vtube.api.playlist.PlaylistDto;
import com.vtube.api.playlist.PlaylistService;
import com.vtube.api.video.VideoDto;
import com.vtube.api.video.VideoSql;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Service
public class SearchService {
    private final Db db;
    private final ChannelService channels;
    private final PlaylistService playlists;

    public SearchService(Db db, ChannelService channels, PlaylistService playlists) {
        this.db = db;
        this.channels = channels;
        this.playlists = playlists;
    }

    /**
     * Kết quả tìm kiếm. Với type=all ở trang 0: thêm tối đa 3 kênh và 10 shorts.
     * hasMore áp dụng cho danh sách chính của type (videos / shorts / channels / playlists).
     */
    public record SearchResult(List<ChannelDto> channels, List<VideoDto> videos, List<VideoDto> shorts,
                               List<PlaylistDto> playlists, int page, boolean hasMore) {
    }

    public record Filters(String type, String uploadDate, String duration, String sort) {
    }

    public SearchResult search(Long uid, String q, Filters f, Paging paging) {
        String keyword = q == null ? "" : q.trim();
        String like = "%" + keyword + "%";
        String type = f.type() == null ? "all" : f.type();
        if (uid != null && paging.page() == 0 && !keyword.isEmpty()) {
            saveKeyword(uid, keyword);
        }
        List<ChannelDto> chs = List.of();
        List<VideoDto> vids = List.of();
        List<VideoDto> shorts = List.of();
        List<PlaylistDto> pls = List.of();
        boolean more = false;
        switch (type) {
            case "channel" -> {
                List<ChannelDto> rows = findChannels(uid, like, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                chs = more ? rows.subList(0, paging.size()) : rows;
            }
            case "playlist" -> {
                List<PlaylistDto> rows = playlists.search(like, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                pls = more ? rows.subList(0, paging.size()) : rows;
            }
            case "short" -> {
                List<VideoDto> rows = findVideos(uid, like, true, f, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                shorts = more ? rows.subList(0, paging.size()) : rows;
            }
            default -> {
                List<VideoDto> rows = findVideos(uid, like, false, f, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                vids = more ? rows.subList(0, paging.size()) : rows;
                if ("all".equals(type) && paging.page() == 0) {
                    chs = findChannels(uid, like, 3, 0);
                    shorts = findVideos(uid, like, true, f, 10, 0);
                }
            }
        }
        return new SearchResult(chs, vids, shorts, pls, paging.page(), more);
    }

    private List<VideoDto> findVideos(Long uid, String like, boolean isShort, Filters f, int limit, int offset) {
        StringBuilder where = new StringBuilder("""
                 WHERE v.visibility = 'public' AND v.is_short = :short
                   AND (v.title LIKE :like OR v.description LIKE :like OR v.tags LIKE :like OR c.name LIKE :like)\s""");
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("like", like)
                .addValue("short", isShort ? 1 : 0).addValue("limit", limit).addValue("offset", offset);
        String since = switch (f.uploadDate() == null ? "" : f.uploadDate()) {
            case "today" -> Times.daysAgo(1);
            case "week" -> Times.daysAgo(7);
            case "month" -> Times.daysAgo(30);
            case "year" -> Times.daysAgo(365);
            default -> null;
        };
        if (since != null) {
            where.append(" AND v.published_at >= :since ");
            p.addValue("since", since);
        }
        switch (f.duration() == null ? "" : f.duration()) {
            case "short" -> where.append(" AND v.duration_seconds < 240 ");
            case "medium" -> where.append(" AND v.duration_seconds BETWEEN 240 AND 1200 ");
            case "long" -> where.append(" AND v.duration_seconds > 1200 ");
            default -> {
            }
        }
        if (uid != null && "unwatched".equals(f.type())) {
            where.append(" AND v.id NOT IN (SELECT video_id FROM watch_history WHERE user_id = :uid) ");
        }
        String order = switch (f.sort() == null ? "relevance" : f.sort()) {
            case "date" -> "v.published_at DESC";
            case "views" -> "v.view_count DESC";
            case "rating" -> "v.like_count DESC";
            default -> "(v.title LIKE :like) DESC, v.view_count DESC";
        };
        return db.jdbc().query(VideoSql.SELECT + where + " ORDER BY " + order + " LIMIT :limit OFFSET :offset",
                p, VideoSql.MAPPER);
    }

    private List<ChannelDto> findChannels(Long uid, String like, int limit, int offset) {
        List<Long> ids = db.jdbc().query("""
                        SELECT id FROM channels WHERE name LIKE :like OR handle LIKE :like
                        ORDER BY subscriber_count DESC LIMIT :limit OFFSET :offset""",
                Db.params().addValue("like", like).addValue("limit", limit).addValue("offset", offset),
                (rs, i) -> rs.getLong(1));
        List<ChannelDto> out = new ArrayList<>();
        for (Long id : ids) {
            out.add(channels.get(uid, id));
        }
        return out;
    }

    /** Lịch sử tìm kiếm (icon đồng hồ) và gợi ý (icon kính lúp). */
    public record Suggestions(List<String> history, List<String> suggestions) {
    }

    public Suggestions suggestions(Long uid, String q) {
        String keyword = q == null ? "" : q.trim();
        List<String> history = uid == null ? List.of() : db.jdbc().query("""
                        SELECT keyword FROM search_history WHERE user_id = :uid AND keyword LIKE :like
                        ORDER BY searched_at DESC LIMIT :limit""",
                Db.params().addValue("uid", uid).addValue("like", "%" + keyword + "%")
                        .addValue("limit", keyword.isEmpty() ? 10 : 3),
                (rs, i) -> rs.getString(1));
        if (keyword.isEmpty()) {
            return new Suggestions(history, List.of());
        }
        List<String> titles = db.jdbc().query("""
                        SELECT v.title FROM videos v JOIN channels c ON c.id = v.channel_id
                        WHERE v.visibility = 'public' AND (v.title LIKE :like OR c.name LIKE :like)
                        ORDER BY (v.title LIKE :prefix) DESC, v.view_count DESC LIMIT 10""",
                Db.params().addValue("like", "%" + keyword + "%").addValue("prefix", keyword + "%"),
                (rs, i) -> rs.getString(1));
        Set<String> set = new LinkedHashSet<>();
        for (String t : titles) {
            if (!history.contains(t)) {
                set.add(t);
            }
        }
        return new Suggestions(history, new ArrayList<>(set));
    }

    public record HistoryEntry(String keyword, String searchedAt) {
    }

    public List<HistoryEntry> history(long uid) {
        return db.jdbc().query(
                "SELECT keyword, searched_at FROM search_history WHERE user_id = :uid ORDER BY searched_at DESC LIMIT 50",
                Db.params().addValue("uid", uid), (rs, i) -> new HistoryEntry(rs.getString(1), rs.getString(2)));
    }

    /** keyword = null để xóa toàn bộ. */
    public void deleteHistory(long uid, String keyword) {
        if (keyword == null || keyword.isBlank()) {
            db.jdbc().update("DELETE FROM search_history WHERE user_id = :uid", Db.params().addValue("uid", uid));
        } else {
            db.jdbc().update("DELETE FROM search_history WHERE user_id = :uid AND keyword = :k",
                    Db.params().addValue("uid", uid).addValue("k", keyword.trim()));
        }
    }

    private void saveKeyword(long uid, String keyword) {
        db.jdbc().update("""
                        INSERT INTO search_history (user_id, keyword, searched_at) VALUES (:uid, :k, :now)
                        ON CONFLICT (user_id, keyword) DO UPDATE SET searched_at = excluded.searched_at""",
                Db.params().addValue("uid", uid).addValue("k", keyword).addValue("now", Times.now()));
    }
}
