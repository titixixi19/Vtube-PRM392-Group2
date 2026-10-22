package com.vtube.api.video;

import com.vtube.api.channel.ChannelBrief;

/**
 * Video trả về cho app. Dùng chung cho feed, shorts, tìm kiếm, lịch sử, playlist...
 * viewer chỉ có giá trị ở API GET /api/videos/{id}, các API khác trả null.
 */
public record VideoDto(
        long id,
        String title,
        String description,
        String thumbnailUrl,
        String videoUrl,
        int durationSeconds,
        long viewCount,
        long likeCount,
        long dislikeCount,
        long commentCount,
        Integer categoryId,
        boolean shortVideo,
        boolean live,
        String visibility,
        boolean commentsEnabled,
        String tags,
        String publishedAt,
        ChannelBrief channel,
        ViewerState viewer) {

    public VideoDto withViewer(ViewerState v) {
        return new VideoDto(id, title, description, thumbnailUrl, videoUrl, durationSeconds, viewCount, likeCount,
                dislikeCount, commentCount, categoryId, shortVideo, live, visibility, commentsEnabled, tags,
                publishedAt, channel, v);
    }
}
