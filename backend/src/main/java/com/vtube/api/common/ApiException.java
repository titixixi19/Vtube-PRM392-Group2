package com.vtube.api.common;

import org.springframework.http.HttpStatus;

/** Ném ra trong service/controller để trả lỗi HTTP có thông điệp tiếng Việt. */
public class ApiException extends RuntimeException {
    private static final long serialVersionUID = 1L;
    private final HttpStatus status;

    public ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }

    public static ApiException badRequest(String message) {
        return new ApiException(HttpStatus.BAD_REQUEST, message);
    }

    public static ApiException unauthorized() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "Bạn cần đăng nhập để thực hiện thao tác này");
    }

    public static ApiException forbidden() {
        return new ApiException(HttpStatus.FORBIDDEN, "Bạn không có quyền thực hiện thao tác này");
    }

    public static ApiException notFound(String what) {
        return new ApiException(HttpStatus.NOT_FOUND, "Không tìm thấy " + what);
    }

    public static ApiException conflict(String message) {
        return new ApiException(HttpStatus.CONFLICT, message);
    }
}
