package co.edu.univalle.clinica.config;

import java.util.List;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Propiedades propias de la aplicación (prefijo "app" en application.properties). */
@ConfigurationProperties(prefix = "app")
public record AppProperties(Jwt jwt, Cors cors) {

    public record Jwt(String secret, long expirationMinutes) {
    }

    public record Cors(List<String> allowedOrigins) {
    }
}
