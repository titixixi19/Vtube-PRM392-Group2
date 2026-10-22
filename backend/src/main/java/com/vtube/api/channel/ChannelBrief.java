package com.vtube.api.channel;

/** Thông tin kênh rút gọn, đi kèm video / bình luận / thông báo. */
public record ChannelBrief(long id, String name, String handle, String avatarUrl, boolean verified,
                           long subscriberCount) {
}
