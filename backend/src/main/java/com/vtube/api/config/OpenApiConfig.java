package com.vtube.api.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Swagger: bấm nút "Authorize" rồi dán token (không cần chữ Bearer) để gọi API cần đăng nhập. */
@Configuration
public class OpenApiConfig {
    @Bean
    public OpenAPI vtubeOpenApi() {
        return new OpenAPI()
                .info(new Info().title("VTube API").version("1.0.0")
                        .description("Backend cho app VTube (PRM393). Tài khoản demo: demo@vtube.vn / 123456"))
                .components(new Components().addSecuritySchemes("bearer",
                        new SecurityScheme().type(SecurityScheme.Type.HTTP).scheme("bearer")))
                .addSecurityItem(new SecurityRequirement().addList("bearer"));
    }
}
