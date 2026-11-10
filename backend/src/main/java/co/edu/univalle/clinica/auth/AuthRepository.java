package co.edu.univalle.clinica.auth;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.Types;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

/** Invoca PKG_SEGURIDAD.LOGIN. Si las credenciales no son válidas, Oracle lanza -20006. */
@Repository
public class AuthRepository {

    public record ResultadoLogin(long idUsuario, String rol, Long idEntidad) {
    }

    private final JdbcTemplate jdbc;

    public AuthRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public ResultadoLogin login(String username, String password) {
        return jdbc.execute((Connection con) -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_SEGURIDAD.LOGIN(?, ?, ?, ?, ?)}")) {
                cs.setString(1, username);
                cs.setString(2, password);
                cs.registerOutParameter(3, Types.NUMERIC);
                cs.registerOutParameter(4, Types.VARCHAR);
                cs.registerOutParameter(5, Types.NUMERIC);
                cs.execute();
                long idEntidad = cs.getLong(5);
                Long entidad = cs.wasNull() ? null : idEntidad;
                return new ResultadoLogin(cs.getLong(3), cs.getString(4), entidad);
            }
        });
    }
}
