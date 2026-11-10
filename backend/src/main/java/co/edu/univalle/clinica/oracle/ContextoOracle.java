package co.edu.univalle.clinica.oracle;

import java.sql.CallableStatement;
import java.sql.Connection;
import java.sql.SQLException;
import java.sql.Types;

import org.springframework.jdbc.core.ConnectionCallback;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Ejecuta trabajo JDBC sobre UNA conexión con el contexto del usuario establecido:
 * PKG_CONTEXTO.SET_USUARIO -> trabajo (procedimientos PL/SQL) -> PKG_CONTEXTO.LIMPIAR.
 * Java no hace COMMIT: la transacción la controlan los procedimientos en Oracle.
 */
@Component
public class ContextoOracle {

    private final JdbcTemplate jdbc;

    public ContextoOracle(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public <T> T ejecutar(UsuarioSesion usuario, ConnectionCallback<T> trabajo) {
        return jdbc.execute((Connection con) -> {
            establecer(con, usuario);
            try {
                return trabajo.doInConnection(con);
            } finally {
                limpiar(con);
            }
        });
    }

    private void establecer(Connection con, UsuarioSesion u) throws SQLException {
        try (CallableStatement cs = con.prepareCall("{call PKG_CONTEXTO.SET_USUARIO(?, ?, ?)}")) {
            cs.setLong(1, u.idUsuario());
            cs.setString(2, u.rol());
            if (u.idEntidad() == null) {
                cs.setNull(3, Types.NUMERIC);
            } else {
                cs.setLong(3, u.idEntidad());
            }
            cs.execute();
        }
    }

    private void limpiar(Connection con) throws SQLException {
        try (CallableStatement cs = con.prepareCall("{call PKG_CONTEXTO.LIMPIAR}")) {
            cs.execute();
        }
    }
}
