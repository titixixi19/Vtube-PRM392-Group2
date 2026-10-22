package com.vtube.api.playlist;

import com.vtube.api.video.VideoDto;

import java.util.List;

/** Màn 14 - Chi tiết playlist. mine = playlist của mình (được sửa, xóa, kéo thả). */
public record PlaylistDetailDto(PlaylistDto playlist, boolean mine, long totalViews, List<Item> items) {

    public record Item(int position, String addedAt, VideoDto video) {
    }
}
