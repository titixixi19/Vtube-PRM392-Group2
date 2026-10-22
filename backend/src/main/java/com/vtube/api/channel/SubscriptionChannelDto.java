package com.vtube.api.channel;

/** Một kênh trong danh sách đã đăng ký (màn 12). hasNew = có video mới trong 7 ngày mà mình chưa xem. */
public record SubscriptionChannelDto(ChannelBrief channel, String notifyMode, boolean hasNew, String lastUploadAt) {
}
