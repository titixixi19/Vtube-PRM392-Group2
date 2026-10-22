package com.vtube.api.user;

import com.vtube.api.auth.Auth;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.Size;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;

@Tag(name = "Me", description = "Màn 4 - Tài khoản đang đăng nhập")
@RestController
@RequestMapping("/api/me")
public class MeController {
    private final UserService users;

    public MeController(UserService users) {
        this.users = users;
    }

    public record UpdateMeRequest(@Size(min = 2, max = 50) String displayName, String avatarUrl) {
    }

    public record SettingsRequest(Boolean historyPaused) {
    }

    @GetMapping
    public MeDto me() {
        return users.getMe(Auth.requireUserId());
    }

    @PutMapping
    public MeDto update(@Valid @RequestBody UpdateMeRequest req) {
        return users.updateMe(Auth.requireUserId(), req.displayName(), req.avatarUrl());
    }

    @PatchMapping("/settings")
    public MeDto settings(@RequestBody SettingsRequest req) {
        long uid = Auth.requireUserId();
        if (req.historyPaused() != null) {
            return users.setHistoryPaused(uid, req.historyPaused());
        }
        return users.getMe(uid);
    }
}
