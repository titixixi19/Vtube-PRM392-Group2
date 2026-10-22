package com.vtube.api.video;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
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

@Tag(name = "Videos", description = "Màn 5, 6, 8, 15 - Feed, xem video, Shorts, tải lên")
@RestController
@RequestMapping("/api")
public class VideoController {
    private final VideoService videos;

    public VideoController(VideoService videos) {
        this.videos = videos;
    }

    public record ReactionRequest(int value) {
    }

    @GetMapping("/categories")
    public List<VideoService.Category> categories() {
        return videos.categories();
    }

    /** category: all | live | recent | music | gaming | news | education | food | travel | tech | entertainment | sports */
    @GetMapping("/videos/feed")
    public PageResult<VideoDto> feed(@RequestParam(required = false) String category,
                                     @RequestParam(required = false) Integer page,
                                     @RequestParam(required = false) Integer size) {
        return videos.feed(Auth.userId(), category, Paging.of(page, size));
    }

    @GetMapping("/shorts")
    public PageResult<VideoDto> shorts(@RequestParam(required = false) Integer page,
                                       @RequestParam(required = false) Integer size) {
        return videos.shorts(Auth.userId(), Paging.of(page, size));
    }

    @GetMapping("/videos/{id}")
    public VideoDto detail(@PathVariable long id) {
        return videos.detail(Auth.userId(), id);
    }

    /** filter: all | channel | related | recent */
    @GetMapping("/videos/{id}/related")
    public PageResult<VideoDto> related(@PathVariable long id,
                                        @RequestParam(defaultValue = "all") String filter,
                                        @RequestParam(required = false) Integer page,
                                        @RequestParam(required = false) Integer size) {
        return videos.related(Auth.userId(), id, filter, Paging.of(page, size));
    }

    @PostMapping("/videos/{id}/view")
    public ResponseEntity<Void> view(@PathVariable long id) {
        videos.addView(id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/videos/{id}/reaction")
    public VideoService.ReactionResult react(@PathVariable long id, @RequestBody ReactionRequest req) {
        return videos.react(Auth.requireUserId(), id, req.value());
    }

    @PostMapping("/videos/{id}/not-interested")
    public ResponseEntity<Void> notInterested(@PathVariable long id) {
        videos.hide(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/videos")
    public ResponseEntity<VideoDto> create(@RequestBody VideoService.SaveVideoRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(videos.create(Auth.requireUserId(), req));
    }

    @PutMapping("/videos/{id}")
    public VideoDto update(@PathVariable long id, @RequestBody VideoService.SaveVideoRequest req) {
        return videos.update(Auth.requireUserId(), id, req);
    }

    @DeleteMapping("/videos/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        videos.delete(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }
}
