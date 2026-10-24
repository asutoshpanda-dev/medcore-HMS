package com.medcore.hms.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;import io.swagger.v3.oas.models.security.SecurityRequirement;

// Swagger UI at /swagger-ui.html, the OpenAPI document at /v3/api-docs.
// Log in with POST /api/auth/login, then press Authorize and paste the access token.
@Configuration
public class OpenApiConfig {

    @Bean
    public OpenAPI medcoreOpenApi() {
        return new OpenAPI()
                .info(new Info()
                        .title("MedCore HMS API")
                        .version("v1")
                        .description("Hospital management API. Every list returns "
                                + "{data, page}; every single item returns {data}; errors use the "
                                + "problem format (RFC 9457)."))
                .addSecurityItem(new SecurityRequirement().addList("bearer-jwt"))
                .components(new Components().addSecuritySchemes("bearer-jwt",
                        new SecurityScheme()
                                .type(SecurityScheme.Type.HTTP)
                                .scheme("bearer")
                                .bearerFormat("JWT")));
    }
}
