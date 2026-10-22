package com.vtube.api.comment;

/**
 * Bình luận. parentId = null là bình luận gốc; khác null là phản hồi.
 * byChannelOwner = người viết là chủ kênh của video (hiện nhãn tên nền xám).
 * myReaction: 1 / -1 / 0 (0 khi là khách).
 */
public record CommentDto(
        long id,
        long videoId,
        Long parentId,
        String content,
        long likeCount,
        long replyCount,
        boolean pinned,
        boolean hearted,
        String createdAt,
        String updatedAt,
        Author author,
        boolean byChannelOwner,
        int myReaction) {

    /** Tác giả bình luận (thông tin lấy từ kênh của user). */
    public record Author(long userId, long channelId, String name, String handle, String avatarUrl) {
    }
}
