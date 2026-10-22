package com.vtube.api;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

/** Chạy: mvn test  — kiểm tra ứng dụng khởi động được (tạo DB, nạp seed). */
@SpringBootTest(properties = "spring.datasource.url=jdbc:sqlite:target/test.db?foreign_keys=true")
class VtubeApiApplicationTests {
    @Test
    void contextLoads() {
    }
}
