package com.vtube.api.common;

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Component;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;

/** Tiện ích nhỏ quanh NamedParameterJdbcTemplate cho SQLite. */
@Component
public class Db {
    private final NamedParameterJdbcTemplate jdbc;

    public Db(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public NamedParameterJdbcTemplate jdbc() {
        return jdbc;
    }

    /**
     * INSERT rồi lấy id vừa tạo. Phải gọi bên trong method @Transactional
     * để câu SELECT last_insert_rowid() chạy trên cùng kết nối.
     */
    public long insert(String sql, MapSqlParameterSource params) {
        jdbc.update(sql, params);
        Long id = jdbc.queryForObject("SELECT last_insert_rowid()", new MapSqlParameterSource(), Long.class);
        return id == null ? 0 : id;
    }

    public boolean exists(String sql, MapSqlParameterSource params) {
        List<Integer> rows = jdbc.query(sql, params, (rs, i) -> 1);
        return !rows.isEmpty();
    }

    public long count(String sql, MapSqlParameterSource params) {
        Long n = jdbc.queryForObject(sql, params, Long.class);
        return n == null ? 0 : n;
    }

    /** Đọc cột INTEGER có thể NULL. */
    public static Long nullableLong(ResultSet rs, String column) throws SQLException {
        long v = rs.getLong(column);
        return rs.wasNull() ? null : v;
    }

    public static Integer nullableInt(ResultSet rs, String column) throws SQLException {
        int v = rs.getInt(column);
        return rs.wasNull() ? null : v;
    }

    public static boolean bool(ResultSet rs, String column) throws SQLException {
        return rs.getInt(column) != 0;
    }

    public static MapSqlParameterSource params() {
        return new MapSqlParameterSource();
    }
}
