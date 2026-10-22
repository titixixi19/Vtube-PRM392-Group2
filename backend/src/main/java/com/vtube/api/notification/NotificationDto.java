package com.vtube.api.notification;

import com.vtube.api.channel.ChannelBrief;

/**
 * type: new_video | new_short | live | comment_reply | comment_heart | new_subscriber
 * App dựa vào type + videoId/commentId/actor để điều hướng khi bấm vào thông báo.
 */
public record NotificationDto(
        long id,
        String type,
        String message,
        boolean read,
        String createdAt,
        ChannelBrief actor,
        Long videoId,
        String videoThumbnailUrl,
        Integer videoDurationSeconds,
        Boolean videoShort,
        Long commentId) {
}
