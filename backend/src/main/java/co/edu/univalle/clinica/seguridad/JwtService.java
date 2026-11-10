package co.edu.univalle.clinica.seguridad;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import co.edu.univalle.clinica.config.AppProperties;

/** Emite el JWT HS256 a partir del resultado de PKG_SEGURIDAD.LOGIN. */
@Service
public class JwtService {

    private final JwtEncoder encoder;
    private final long minutos;

    public JwtService(JwtEncoder encoder, AppProperties props) {
        this.encoder = encoder;
        this.minutos = props.jwt().expirationMinutes();
    }

    public String emitir(long idUsuario, String username, String rol, Long idEntidad) {
        Instant ahora = Instant.now();
        JwtClaimsSet.Builder claims = JwtClaimsSet.builder()
                .issuer("clinica")
                .subject(String.valueOf(idUsuario))
                .issuedAt(ahora)
                .expiresAt(ahora.plus(minutos, ChronoUnit.MINUTES))
                .claim("username", username)
                .claim("rol", rol);
        if (idEntidad != null) {
            claims.claim("idEntidad", idEntidad);
        }
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims.build())).getTokenValue();
    }
}
