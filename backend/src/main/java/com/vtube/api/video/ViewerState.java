package com.vtube.api.video;

/**
 * Trạng thái của người đang xem với 1 video (chỉ có khi đã đăng nhập, ở API chi tiết video).
 * myReaction: 1 = đã like, -1 = đã dislike, 0 = chưa.
 */
public record ViewerState(int myReaction, boolean subscribed, String notifyMode, int progressSeconds,
                          boolean inWatchLater, boolean owner) {
}
