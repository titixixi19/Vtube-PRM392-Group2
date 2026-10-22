package com.vtube.api.history;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@Tag(name = "History", description = "Màn 13 - Lịch sử xem")
@RestController
@RequestMapping("/api/me/history")
public class HistoryController {
    private final HistoryService history;

    public HistoryController(HistoryService history) {
        this.history = history;
    }

    public record ProgressRequest(int progressSeconds) {
    }

    /** type: all | video | short | music */
    @GetMapping
    public PageResult<HistoryService.HistoryItem> list(@RequestParam(defaultValue = "all") String type,
                                                       @RequestParam(required = false) String q,
                                                       @RequestParam(required = false) Integer page,
                                                       @RequestParam(required = false) Integer size) {
        return history.list(Auth.requireUserId(), type, q, Paging.of(page, size));
    }

    @PutMapping("/{videoId}")
    public HistoryService.SaveResult save(@PathVariable long videoId, @RequestBody ProgressRequest req) {
        return history.save(Auth.requireUserId(), videoId, req.progressSeconds());
    }

    @DeleteMapping("/{videoId}")
    public ResponseEntity<Void> delete(@PathVariable long videoId) {
        history.delete(Auth.requireUserId(), videoId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> clear() {
        history.clear(Auth.requireUserId());
        return ResponseEntity.noContent().build();
    }
}
