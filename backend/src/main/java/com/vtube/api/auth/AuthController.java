package com.vtube.api.auth;

import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@Tag(name = "Auth", description = "Màn 2, 3 - Đăng nhập, đăng ký")
@RestController
@RequestMapping("/api")
public class AuthController {
    private final AuthService auth;

    public AuthController(AuthService auth) {
        this.auth = auth;
    }

    public record LoginRequest(@NotBlank @Email String email, @NotBlank String password) {
    }

    public record RegisterRequest(
            @NotBlank @Size(min = 2, max = 50) String displayName,
            @Size(max = 50) String channelName,
            @NotBlank @Pattern(regexp = "@?[a-zA-Z0-9._]{3,30}", message = "3-30 ký tự: chữ, số, dấu chấm, gạch dưới") String handle,
            @NotBlank @Email String email,
            @NotBlank @Size(min = 6, max = 100) String password,
            String avatarUrl) {
    }

    @PostMapping("/auth/login")
    public AuthService.AuthResponse login(@Valid @RequestBody LoginRequest req) {
        return auth.login(req.email(), req.password());
    }

    @PostMapping("/auth/register")
    public ResponseEntity<AuthService.AuthResponse> register(@Valid @RequestBody RegisterRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED).body(auth.register(req));
    }

    @PostMapping("/auth/logout")
    public ResponseEntity<Void> logout(@RequestHeader(value = "Authorization", required = false) String header) {
        auth.logout(header);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/users/check-handle")
    public Map<String, Boolean> checkHandle(@RequestParam String handle) {
        return Map.of("available", auth.isHandleAvailable(handle));
    }
}
