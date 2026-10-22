package com.vtube.api.playlist;

import com.vtube.api.auth.Auth;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@Tag(name = "Playlists", description = "Màn 4, 14 - Danh sách phát, Xem sau, Video đã thích")
@RestController
@RequestMapping("/api")
public class PlaylistController {
    private final PlaylistService playlists;

    public PlaylistController(PlaylistService playlists) {
        this.playlists = playlists;
    }

    public record SavePlaylistRequest(String title, String description, String visibility) {
    }

    public record AddVideoRequest(long videoId) {
    }

    public record ReorderRequest(List<Long> videoIds) {
    }

    /** videoId (tùy chọn): trả thêm containsVideo cho sheet "Lưu vào danh sách phát". */
    @GetMapping("/me/playlists")
    public List<PlaylistDto> mine(@RequestParam(required = false) Long videoId) {
        return playlists.mine(Auth.requireUserId(), videoId);
    }

    @GetMapping("/channels/{channelId}/playlists")
    public List<PlaylistDto> ofChannel(@PathVariable long channelId) {
        return playlists.ofChannel(Auth.userId(), channelId);
    }

    @PostMapping("/playlists")
    public ResponseEntity<PlaylistDto> create(@RequestBody SavePlaylistRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(playlists.create(Auth.requireUserId(), req.title(), req.description(), req.visibility()));
    }

    /** sort: manual | added_new | added_old | popular | published */
    @GetMapping("/playlists/{id}")
    public PlaylistDetailDto detail(@PathVariable long id, @RequestParam(defaultValue = "manual") String sort) {
        return playlists.detail(Auth.userId(), id, sort);
    }

    @PutMapping("/playlists/{id}")
    public PlaylistDto update(@PathVariable long id, @RequestBody SavePlaylistRequest req) {
        return playlists.update(Auth.requireUserId(), id, req.title(), req.description(), req.visibility());
    }

    @DeleteMapping("/playlists/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        playlists.delete(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/playlists/{id}/videos")
    public PlaylistDto addVideo(@PathVariable long id, @RequestBody AddVideoRequest req) {
        return playlists.addVideo(Auth.requireUserId(), id, req.videoId());
    }

    @DeleteMapping("/playlists/{id}/videos/{videoId}")
    public PlaylistDto removeVideo(@PathVariable long id, @PathVariable long videoId) {
        return playlists.removeVideo(Auth.requireUserId(), id, videoId);
    }

    @PutMapping("/playlists/{id}/order")
    public PlaylistDto reorder(@PathVariable long id, @RequestBody ReorderRequest req) {
        return playlists.reorder(Auth.requireUserId(), id, req.videoIds() == null ? List.of() : req.videoIds());
    }

    @PutMapping("/me/watch-later/{videoId}")
    public PlaylistDto addWatchLater(@PathVariable long videoId) {
        return playlists.setWatchLater(Auth.requireUserId(), videoId, true);
    }

    @DeleteMapping("/me/watch-later/{videoId}")
    public PlaylistDto removeWatchLater(@PathVariable long videoId) {
        return playlists.setWatchLater(Auth.requireUserId(), videoId, false);
    }
}
