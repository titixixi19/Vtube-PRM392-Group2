package com.vtube.api.playlist;

/**
 * Playlist rút gọn (danh sách). kind: liked | watch_later | custom.
 * containsVideo chỉ có khi gọi /api/me/playlists?videoId=... (dùng cho sheet "Lưu vào danh sách phát").
 */
public record PlaylistDto(
        long id,
        String title,
        String description,
        String visibility,
        String kind,
        long videoCount,
        String thumbnailUrl,
        String updatedAt,
        long ownerUserId,
        String ownerName,
        long ownerChannelId,
        Boolean containsVideo) {
}
