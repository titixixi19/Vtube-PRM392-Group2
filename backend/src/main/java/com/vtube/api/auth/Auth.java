package com.vtube.api.auth;

import com.vtube.api.common.ApiException;
import org.springframework.web.context.request.RequestAttributes;
import org.springframework.web.context.request.RequestContextHolder;

/**
 * Lấy user đang đăng nhập trong request hiện tại.
 * AuthInterceptor đã đọc header "Authorization: Bearer <token>" và gắn userId vào request.
 *
 * <pre>
 *   Long uid = Auth.userId();          // null nếu là khách
 *   long uid = Auth.requireUserId();   // ném 401 nếu chưa đăng nhập
 * </pre>
 */
public final class Auth {
    static final String ATTR = "vtube.userId";

    private Auth() {
    }

    public static Long userId() {
        RequestAttributes attrs = RequestContextHolder.getRequestAttributes();
        if (attrs == null) {
            return null;
        }
        Object v = attrs.getAttribute(ATTR, RequestAttributes.SCOPE_REQUEST);
        return v instanceof Long l ? l : null;
    }

    public static long requireUserId() {
        Long uid = userId();
        if (uid == null) {
            throw ApiException.unauthorized();
        }
        return uid;
    }
}
