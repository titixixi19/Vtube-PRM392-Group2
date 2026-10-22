package com.vtube.api.user;

import com.vtube.api.channel.ChannelBrief;

/** Thông tin tài khoản đang đăng nhập (GET /api/me). channel = kênh của chính user. */
public record MeDto(long id, String email, String displayName, String avatarUrl, boolean historyPaused,
                    String createdAt, ChannelBrief channel) {
}
