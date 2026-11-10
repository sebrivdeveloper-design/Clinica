package co.edu.univalle.clinica.seguridad;

import org.springframework.security.oauth2.jwt.Jwt;

/** Datos del usuario autenticado, leídos del JWT. Se envían a Oracle mediante PKG_CONTEXTO. */
public record UsuarioSesion(Long idUsuario, String rol, Long idEntidad) {

    public static UsuarioSesion desde(Jwt jwt) {
        Number entidad = jwt.getClaim("idEntidad");
        return new UsuarioSesion(
                Long.valueOf(jwt.getSubject()),
                jwt.getClaimAsString("rol"),
                entidad == null ? null : entidad.longValue());
    }
}
