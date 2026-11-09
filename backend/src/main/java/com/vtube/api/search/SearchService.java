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

    public static String unaccent(String s) {
        if (s == null) return "";
        String nfd = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD);
        return nfd.replaceAll("\\p{InCombiningDiacriticalMarks}+", "")
                .replace('đ', 'd').replace('Đ', 'D')
                .toLowerCase();
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
                List<ChannelDto> rows = findChannels(uid, keyword, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                chs = more ? rows.subList(0, paging.size()) : rows;
            }
            case "playlist" -> {
                List<PlaylistDto> rows = playlists.search(like, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                pls = more ? rows.subList(0, paging.size()) : rows;
            }
            case "short" -> {
                List<VideoDto> rows = findVideos(uid, keyword, true, f, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                shorts = more ? rows.subList(0, paging.size()) : rows;
            }
            default -> {
                List<VideoDto> rows = findVideos(uid, keyword, false, f, paging.limitPlusOne(), paging.offset());
                more = rows.size() > paging.size();
                vids = more ? rows.subList(0, paging.size()) : rows;
                if ("all".equals(type) && paging.page() == 0) {
                    chs = findChannels(uid, keyword, 3, 0);
                    shorts = findVideos(uid, keyword, true, f, 10, 0);
                }
            }
        }
        return new SearchResult(chs, vids, shorts, pls, paging.page(), more);
    }

    private List<VideoDto> findVideos(Long uid, String keyword, boolean isShort, Filters f, int limit, int offset) {
        String like = "%" + keyword + "%";
        String noSpaceLike = "%" + keyword.replaceAll("\\s+", "") + "%";
        String unaccentedKeyword = unaccent(keyword);

        StringBuilder where = new StringBuilder("""
                 WHERE v.visibility = 'public' AND v.is_short = :short
                   AND (v.title LIKE :like OR v.description LIKE :like OR v.tags LIKE :like OR c.name LIKE :like OR c.handle LIKE :noSpaceLike)\s""");
        MapSqlParameterSource p = Db.params().addValue("uid", uid).addValue("like", like)
                .addValue("noSpaceLike", noSpaceLike)
                .addValue("short", isShort ? 1 : 0);
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

        List<VideoDto> list = new ArrayList<>(db.jdbc().query(VideoSql.SELECT + where + " ORDER BY " + order, p, VideoSql.MAPPER));
        if (!unaccentedKeyword.isEmpty()) {
            StringBuilder extraWhere = new StringBuilder("""
                     WHERE v.visibility = 'public' AND v.is_short = :short\s""");
            MapSqlParameterSource extraP = Db.params()
                    .addValue("uid", uid)
                    .addValue("like", like)
                    .addValue("short", isShort ? 1 : 0);
            if (since != null) {
                extraWhere.append(" AND v.published_at >= :since ");
                extraP.addValue("since", since);
            }
            if (f.duration() != null) {
                switch (f.duration()) {
                    case "short" -> extraWhere.append(" AND v.duration_seconds < 240 ");
                    case "medium" -> extraWhere.append(" AND v.duration_seconds BETWEEN 240 AND 1200 ");
                    case "long" -> extraWhere.append(" AND v.duration_seconds > 1200 ");
                }
            }
            if (uid != null && "unwatched".equals(f.type())) {
                extraWhere.append(" AND v.id NOT IN (SELECT video_id FROM watch_history WHERE user_id = :uid) ");
            }
            String extraOrder = switch (f.sort() == null ? "relevance" : f.sort()) {
                case "date" -> "v.published_at DESC";
                case "views" -> "v.view_count DESC";
                case "rating" -> "v.like_count DESC";
                default -> "v.view_count DESC";
            };
            List<VideoDto> allCandidates = db.jdbc().query(VideoSql.SELECT + extraWhere + " ORDER BY " + extraOrder, extraP, VideoSql.MAPPER);
            Set<Long> existingIds = new java.util.HashSet<>();
            for (VideoDto v : list) existingIds.add(v.id());
            for (VideoDto v : allCandidates) {
                if (!existingIds.contains(v.id())) {
                    if (unaccent(v.title()).contains(unaccentedKeyword)
                            || (v.channel() != null && unaccent(v.channel().name()).contains(unaccentedKeyword))
                            || (v.channel() != null && unaccent(v.channel().handle()).contains(unaccentedKeyword))) {
                        list.add(v);
                        existingIds.add(v.id());
                    }
                }
            }
        }

        int from = Math.min(offset, list.size());
        int to = Math.min(from + limit, list.size());
        return list.subList(from, to);
    }

    private List<ChannelDto> findChannels(Long uid, String keyword, int limit, int offset) {
        String unaccentedKeyword = unaccent(keyword);
        String unaccentedNoSpace = unaccentedKeyword.replaceAll("\\s+", "");

        List<Object[]> rows = db.jdbc().query("""
                        SELECT id, name, handle FROM channels
                        ORDER BY subscriber_count DESC""",
                (rs, i) -> new Object[]{rs.getLong(1), rs.getString(2), rs.getString(3)});

        List<Long> matchedIds = new ArrayList<>();
        for (Object[] row : rows) {
            Long id = (Long) row[0];
            String name = row[1] == null ? "" : (String) row[1];
            String handle = row[2] == null ? "" : (String) row[2];

            boolean match = name.toLowerCase().contains(keyword.toLowerCase())
                    || handle.toLowerCase().contains(keyword.toLowerCase())
                    || handle.toLowerCase().contains(keyword.replaceAll("\\s+", "").toLowerCase())
                    || unaccent(name).contains(unaccentedKeyword)
                    || unaccent(handle).contains(unaccentedNoSpace);

            if (match) {
                matchedIds.add(id);
            }
        }

        int from = Math.min(offset, matchedIds.size());
        int to = Math.min(from + limit, matchedIds.size());
        List<Long> pagedIds = matchedIds.subList(from, to);

        List<ChannelDto> out = new ArrayList<>();
        for (Long id : pagedIds) {
            out.add(channels.get(uid, id));
        }
        return out;
    }

    /** Lịch sử tìm kiếm (icon đồng hồ) và gợi ý (icon kính lúp). */
    public record Suggestions(List<String> history, List<String> suggestions) {
    }

    public Suggestions suggestions(Long uid, String q) {
        String keyword = q == null ? "" : q.trim();
        String unaccentedKeyword = unaccent(keyword);
        String noSpace = keyword.replaceAll("\\s+", "").toLowerCase();

        List<String> history = uid == null ? List.of() : db.jdbc().query("""
                        SELECT keyword FROM search_history WHERE user_id = :uid
                        ORDER BY searched_at DESC LIMIT 20""",
                Db.params().addValue("uid", uid),
                (rs, i) -> rs.getString(1));

        List<String> matchedHistory = new ArrayList<>();
        if (!keyword.isEmpty()) {
            for (String h : history) {
                if (h.toLowerCase().contains(keyword.toLowerCase()) || unaccent(h).contains(unaccentedKeyword)) {
                    matchedHistory.add(h);
                    if (matchedHistory.size() >= 3) break;
                }
            }
        } else {
            matchedHistory = history.stream().limit(10).toList();
        }

        if (keyword.isEmpty()) {
            return new Suggestions(matchedHistory, List.of());
        }

        List<Object[]> candidates = db.jdbc().query("""
                        SELECT v.title, c.name, c.handle FROM videos v JOIN channels c ON c.id = v.channel_id
                        WHERE v.visibility = 'public'
                        ORDER BY v.view_count DESC LIMIT 100""",
                (rs, i) -> new Object[]{rs.getString(1), rs.getString(2), rs.getString(3)});

        Set<String> set = new LinkedHashSet<>();
        for (Object[] row : candidates) {
            String title = (String) row[0];
            String channelName = (String) row[1];
            String handle = (String) row[2];

            if (channelName != null && (channelName.toLowerCase().contains(keyword.toLowerCase())
                    || unaccent(channelName).contains(unaccentedKeyword)
                    || (handle != null && handle.toLowerCase().contains(noSpace)))) {
                if (!matchedHistory.contains(channelName)) {
                    set.add(channelName);
                }
            }
            if (title != null && (title.toLowerCase().contains(keyword.toLowerCase())
                    || unaccent(title).contains(unaccentedKeyword))) {
                if (!matchedHistory.contains(title)) {
                    set.add(title);
                }
            }
            if (set.size() >= 10) break;
        }

        return new Suggestions(matchedHistory, new ArrayList<>(set));
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
