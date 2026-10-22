package com.vtube.api.common;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

/** Thời gian lưu trong DB dạng chuỗi ISO-8601 UTC (2026-10-22T04:30:00Z). */
public final class Times {
    private Times() {
    }

    public static String now() {
        return Instant.now().truncatedTo(ChronoUnit.SECONDS).toString();
    }

    public static String daysFromNow(int days) {
        return Instant.now().plus(days, ChronoUnit.DAYS).truncatedTo(ChronoUnit.SECONDS).toString();
    }

    public static String daysAgo(int days) {
        return daysFromNow(-days);
    }
}
