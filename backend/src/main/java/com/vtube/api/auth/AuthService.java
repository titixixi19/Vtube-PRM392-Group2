package com.vtube.api.auth;

import com.vtube.api.common.ApiException;
import com.vtube.api.common.Db;
import com.vtube.api.common.Times;
import com.vtube.api.user.MeDto;
import com.vtube.api.user.UserService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class AuthService {
    private final Db db;
    private final UserService users;
    private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
    private final int tokenDays;

    public AuthService(Db db, UserService users, @Value("${app.token-days}") int tokenDays) {
        this.db = db;
        this.users = users;
        this.tokenDays = tokenDays;
    }

    public record AuthResponse(String token, MeDto user) {
    }

    public boolean isHandleAvailable(String handle) {
        return !db.exists("SELECT 1 FROM channels WHERE handle = :h", Db.params().addValue("h", normalizeHandle(handle)));
    }

    @Transactional
    public AuthResponse register(AuthController.RegisterRequest req) {
        String email = req.email().trim().toLowerCase();
        String handle = normalizeHandle(req.handle());
        if (db.exists("SELECT 1 FROM users WHERE email = :e", Db.params().addValue("e", email))) {
            throw ApiException.conflict("Email đã được sử dụng");
        }
        if (!isHandleAvailable(handle)) {
            throw ApiException.conflict("Handle @" + handle + " đã có người sử dụng");
        }
        String avatar = req.avatarUrl() == null || req.avatarUrl().isBlank() ? null : req.avatarUrl().trim();
        long uid = db.insert("""
                        INSERT INTO users (email, password_hash, display_name, avatar_url)
                        VALUES (:email, :hash, :name, :avatar)""",
                Db.params().addValue("email", email).addValue("hash", encoder.encode(req.password()))
                        .addValue("name", req.displayName().trim()).addValue("avatar", avatar));
        String channelName = req.channelName() == null || req.channelName().isBlank()
                ? req.displayName().trim() : req.channelName().trim();
        db.jdbc().update("""
                        INSERT INTO channels (user_id, name, handle, avatar_url)
                        VALUES (:uid, :name, :handle, :avatar)""",
                Db.params().addValue("uid", uid).addValue("name", channelName).addValue("handle", handle)
                        .addValue("avatar", avatar));
        // 2 playlist hệ thống
        db.jdbc().update("""
                        INSERT INTO playlists (user_id, title, visibility, kind) VALUES
                        (:uid, 'Video đã thích', 'private', 'liked'),
                        (:uid, 'Xem sau', 'private', 'watch_later')""",
                Db.params().addValue("uid", uid));
        return new AuthResponse(createToken(uid), users.getMe(uid));
    }

    private record Credential(long id, String hash) {
    }

    public AuthResponse login(String email, String password) {
        List<Credential> rows = db.jdbc().query("SELECT id, password_hash FROM users WHERE email = :e",
                Db.params().addValue("e", email.trim().toLowerCase()),
                (rs, i) -> new Credential(rs.getLong("id"), rs.getString("password_hash")));
        if (rows.isEmpty() || !encoder.matches(password, rows.get(0).hash())) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "Email hoặc mật khẩu không đúng");
        }
        long uid = rows.get(0).id();
        return new AuthResponse(createToken(uid), users.getMe(uid));
    }

    public void logout(String authorizationHeader) {
        if (authorizationHeader != null && authorizationHeader.startsWith("Bearer ")) {
            db.jdbc().update("DELETE FROM auth_tokens WHERE token = :t",
                    Db.params().addValue("t", authorizationHeader.substring(7).trim()));
        }
    }

    private String createToken(long uid) {
        String token = UUID.randomUUID().toString().replace("-", "") + UUID.randomUUID().toString().replace("-", "");
        db.jdbc().update("INSERT INTO auth_tokens (token, user_id, expires_at) VALUES (:t, :uid, :exp)",
                Db.params().addValue("t", token).addValue("uid", uid).addValue("exp", Times.daysFromNow(tokenDays)));
        return token;
    }

    private static String normalizeHandle(String handle) {
        String h = handle == null ? "" : handle.trim();
        if (h.startsWith("@")) {
            h = h.substring(1);
        }
        return h.toLowerCase();
    }
}
