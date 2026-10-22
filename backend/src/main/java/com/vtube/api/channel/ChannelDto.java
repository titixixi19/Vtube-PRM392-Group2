package com.vtube.api.channel;

/**
 * Trang kênh (màn 11). subscribed/notifyMode theo người đang xem; mine = kênh của chính mình.
 */
public record ChannelDto(
        long id,
        long userId,
        String name,
        String handle,
        String description,
        String avatarUrl,
        String bannerUrl,
        boolean verified,
        long subscriberCount,
        long videoCount,
        long totalViews,
        String createdAt,
        boolean subscribed,
        String notifyMode,
        boolean mine) {
}
