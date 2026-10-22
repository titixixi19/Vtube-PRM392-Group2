package com.vtube.api.common;

/** page bắt đầu từ 0, size từ 1 đến 50 (mặc định 20). */
public record Paging(int page, int size) {

    public static Paging of(Integer page, Integer size) {
        int p = page == null || page < 0 ? 0 : page;
        int s = size == null || size < 1 ? 20 : Math.min(size, 50);
        return new Paging(p, s);
    }

    public int offset() {
        return page * size;
    }

    /** Lấy dư 1 dòng để biết còn trang sau hay không. */
    public int limitPlusOne() {
        return size + 1;
    }
}
