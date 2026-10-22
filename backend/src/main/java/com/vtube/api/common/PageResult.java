package com.vtube.api.common;

import java.util.List;

/**
 * Kết quả phân trang dùng chung: { items, page, size, hasMore }.
 * Flutter tải trang tiếp theo khi hasMore = true.
 */
public record PageResult<T>(List<T> items, int page, int size, boolean hasMore) {

    /** rows được truy vấn với LIMIT size + 1; nếu dư 1 phần tử nghĩa là còn trang sau. */
    public static <T> PageResult<T> of(List<T> rows, Paging paging) {
        boolean more = rows.size() > paging.size();
        List<T> items = more ? rows.subList(0, paging.size()) : rows;
        return new PageResult<>(items, paging.page(), paging.size(), more);
    }
}
