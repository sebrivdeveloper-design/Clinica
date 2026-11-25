package co.edu.univalle.clinica.catalogo;

import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.oracle.CursorMapper;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;
import oracle.jdbc.OracleTypes;

/** PKG_CITAS.PRO_LISTAR_MEDICOS y PRO_LISTAR_PACIENTES (solo lectura). */
@Repository
public class CatalogoRepository {

    private final ContextoOracle contexto;

    public CatalogoRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    public List<Map<String, Object>> medicos(UsuarioSesion u) {
        return cursor(u, "{call PKG_CITAS.PRO_LISTAR_MEDICOS(?)}");
    }

    public List<Map<String, Object>> pacientes(UsuarioSesion u) {
        return cursor(u, "{call PKG_CITAS.PRO_LISTAR_PACIENTES(?)}");
    }

    private List<Map<String, Object>> cursor(UsuarioSesion u, String llamada) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall(llamada)) {
                cs.registerOutParameter(1, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(1)) {
                    return CursorMapper.aLista(rs);
                }
            }
        });
    }
}
