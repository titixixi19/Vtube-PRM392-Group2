package com.vtube.api.comment;

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

@Tag(name = "Comments", description = "Màn 7 - Bình luận")
@RestController
@RequestMapping("/api")
public class CommentController {
    private final CommentService comments;

    public CommentController(CommentService comments) {
        this.comments = comments;
    }

    public record CreateCommentRequest(String content, Long parentId) {
    }

    public record UpdateCommentRequest(String content) {
    }

    public record ReactionRequest(int value) {
    }

    /** sort: top | new */
    @GetMapping("/videos/{videoId}/comments")
    public PageResult<CommentDto> list(@PathVariable long videoId,
                                       @RequestParam(defaultValue = "top") String sort,
                                       @RequestParam(required = false) Integer page,
                                       @RequestParam(required = false) Integer size) {
        return comments.list(Auth.userId(), videoId, sort, Paging.of(page, size));
    }

    @GetMapping("/comments/{id}/replies")
    public PageResult<CommentDto> replies(@PathVariable long id,
                                          @RequestParam(required = false) Integer page,
                                          @RequestParam(required = false) Integer size) {
        return comments.replies(Auth.userId(), id, Paging.of(page, size));
    }

    @PostMapping("/videos/{videoId}/comments")
    public ResponseEntity<CommentDto> create(@PathVariable long videoId, @RequestBody CreateCommentRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(comments.create(Auth.requireUserId(), videoId, req.content(), req.parentId()));
    }

    @PutMapping("/comments/{id}")
    public CommentDto update(@PathVariable long id, @RequestBody UpdateCommentRequest req) {
        return comments.update(Auth.requireUserId(), id, req.content());
    }

    @DeleteMapping("/comments/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        comments.delete(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/comments/{id}/reaction")
    public CommentDto react(@PathVariable long id, @RequestBody ReactionRequest req) {
        return comments.react(Auth.requireUserId(), id, req.value());
    }

    @PutMapping("/comments/{id}/pin")
    public CommentDto pin(@PathVariable long id) {
        return comments.togglePin(Auth.requireUserId(), id);
    }

    @PutMapping("/comments/{id}/heart")
    public CommentDto heart(@PathVariable long id) {
        return comments.toggleHeart(Auth.requireUserId(), id);
    }
}
