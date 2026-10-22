package com.vtube.api.auth;

import com.vtube.api.common.Db;
import com.vtube.api.common.Times;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.stereotype.Component;
import org.springframework.web.servlet.HandlerInterceptor;

import java.util.List;

/** Đọc token (nếu có) và gắn userId vào request. Không chặn khách; từng API tự gọi Auth.requireUserId(). */
@Component
public class AuthInterceptor implements HandlerInterceptor {
    private final Db db;

    public AuthInterceptor(Db db) {
        this.db = db;
    }

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            String token = header.substring(7).trim();
            List<Long> ids = db.jdbc().query(
                    "SELECT user_id FROM auth_tokens WHERE token = :t AND expires_at > :now",
                    Db.params().addValue("t", token).addValue("now", Times.now()),
                    (rs, i) -> rs.getLong(1));
            if (!ids.isEmpty()) {
                request.setAttribute(Auth.ATTR, ids.get(0));
            }
        }
        return true;
    }
}
