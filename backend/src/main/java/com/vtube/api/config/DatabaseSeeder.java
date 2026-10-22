package com.vtube.api.config;

import com.vtube.api.common.Db;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;

/** Nạp dữ liệu mẫu (seed.sql) khi bảng users còn trống. Xóa vtube.db để nạp lại từ đầu. */
@Component
public class DatabaseSeeder implements CommandLineRunner {
    private static final Logger log = LoggerFactory.getLogger(DatabaseSeeder.class);
    private final Db db;
    private final DataSource dataSource;

    public DatabaseSeeder(Db db, DataSource dataSource) {
        this.db = db;
        this.dataSource = dataSource;
    }

    @Override
    public void run(String... args) {
        long users = db.count("SELECT COUNT(*) FROM users", Db.params());
        if (users > 0) {
            log.info("Database đã có {} user, bỏ qua seed", users);
            return;
        }
        ResourceDatabasePopulator populator = new ResourceDatabasePopulator(new ClassPathResource("seed.sql"));
        populator.setSqlScriptEncoding("UTF-8");
        populator.execute(dataSource);
        log.info("Đã nạp dữ liệu mẫu. Tài khoản demo: demo@vtube.vn / 123456");
    }
}
