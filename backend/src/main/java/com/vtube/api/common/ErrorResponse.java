package com.vtube.api.common;

/** Body JSON của mọi lỗi: { "status": 404, "error": "Not Found", "message": "Không tìm thấy video" } */
public record ErrorResponse(int status, String error, String message) {
}
