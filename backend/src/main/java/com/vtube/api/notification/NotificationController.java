package com.vtube.api.notification;

import com.vtube.api.auth.Auth;
import com.vtube.api.common.PageResult;
import com.vtube.api.common.Paging;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Tag(name = "Notifications", description = "Màn 16 - Thông báo")
@RestController
@RequestMapping("/api")
public class NotificationController {
    private final NotificationService service;

    public NotificationController(NotificationService service) {
        this.service = service;
    }

    @GetMapping("/me/notifications")
    public PageResult<NotificationDto> list(@RequestParam(defaultValue = "all") String type,
                                            @RequestParam(required = false) Integer page,
                                            @RequestParam(required = false) Integer size) {
        return service.list(Auth.requireUserId(), type, Paging.of(page, size));
    }

    @GetMapping("/me/notifications/unread-count")
    public Map<String, Long> unreadCount() {
        return Map.of("count", service.unreadCount(Auth.requireUserId()));
    }

    @PutMapping("/me/notifications/read-all")
    public ResponseEntity<Void> readAll() {
        service.markAllRead(Auth.requireUserId());
        return ResponseEntity.noContent().build();
    }

    @PutMapping("/notifications/{id}/read")
    public ResponseEntity<Void> read(@PathVariable long id) {
        service.markRead(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/notifications/{id}")
    public ResponseEntity<Void> delete(@PathVariable long id) {
        service.delete(Auth.requireUserId(), id);
        return ResponseEntity.noContent().build();
    }
}
