package co.edu.univalle.clinica.farmacia;

import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.sql.Types;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.farmacia.FarmaciaController.DetalleRequest;
import co.edu.univalle.clinica.farmacia.FarmaciaController.EntregaRequest;
import co.edu.univalle.clinica.farmacia.FarmaciaController.RecetaRequest;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.oracle.CursorMapper;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Punto UNICO de integracion con PKG_FARMACIA (HU05).
 * Java solo llama a los procedimientos y traslada sus resultados: las reglas, los permisos, el
 * stock y los estados los decide Oracle. Los procedimientos de escritura hacen su propio COMMIT;
 * los errores -20xxx suben como SQLException y los traduce GlobalExceptionHandler.
 * Los cursores se registran con java.sql.Types.REF_CURSOR (no hace falta importar clases de Oracle).
 */
@Repository
public class FarmaciaRepository {

    private final ContextoOracle contexto;

    public FarmaciaRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    /** PKG_FARMACIA.PRO_CREAR_RECETA(idHistoria, OUT idReceta) -> {idReceta}. */
    public Map<String, Object> crearReceta(UsuarioSesion u, RecetaRequest req) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_FARMACIA.PRO_CREAR_RECETA(?, ?)}")) {
                cs.setLong(1, req.idHistoria());
                cs.registerOutParameter(2, Types.NUMERIC);
                cs.execute();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idReceta", cs.getLong(2));
                return r;
            }
        });
    }

    /** PKG_FARMACIA.PRO_AGREGAR_DETALLE(idReceta, idMedicamento, cantidad, dosis, OUT idDetalle) -> {idDetalle}. */
    public Map<String, Object> agregarDetalle(UsuarioSesion u, Long idReceta, DetalleRequest req) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con
                    .prepareCall("{call PKG_FARMACIA.PRO_AGREGAR_DETALLE(?, ?, ?, ?, ?)}")) {
                cs.setLong(1, idReceta);
                cs.setLong(2, req.idMedicamento());
                cs.setInt(3, req.cantidad());
                cs.setString(4, req.dosis());
                cs.registerOutParameter(5, Types.NUMERIC);
                cs.execute();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("idDetalle", cs.getLong(5));
                return r;
            }
        });
    }

    /**
     * PKG_FARMACIA.PRO_REGISTRAR_ENTREGA(idDetalle, cantidad, OUT pendiente, OUT estadoDetalle, OUT estadoReceta).
     * El farmaceutico sale del contexto (JWT), no del cuerpo de la peticion.
     */
    public Map<String, Object> registrarEntrega(UsuarioSesion u, Long idDetalle, EntregaRequest req) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con
                    .prepareCall("{call PKG_FARMACIA.PRO_REGISTRAR_ENTREGA(?, ?, ?, ?, ?)}")) {
                cs.setLong(1, idDetalle);
                cs.setInt(2, req.cantidad());
                cs.registerOutParameter(3, Types.NUMERIC);
                cs.registerOutParameter(4, Types.VARCHAR);
                cs.registerOutParameter(5, Types.VARCHAR);
                cs.execute();
                Map<String, Object> r = new LinkedHashMap<>();
                r.put("cantidadPendiente", cs.getLong(3));
                r.put("estadoDetalle", cs.getString(4));
                r.put("estadoReceta", cs.getString(5));
                return r;
            }
        });
    }

    /** PKG_FARMACIA.PRO_LISTAR_MEDICAMENTOS(OUT cursor). */
    public List<Map<String, Object>> medicamentos(UsuarioSesion u) {
        return consultarCursor(u, "{call PKG_FARMACIA.PRO_LISTAR_MEDICAMENTOS(?)}", null);
    }

    /** PKG_FARMACIA.PRO_DETALLES_PENDIENTES(OUT cursor). */
    public List<Map<String, Object>> detallesPendientes(UsuarioSesion u) {
        return consultarCursor(u, "{call PKG_FARMACIA.PRO_DETALLES_PENDIENTES(?)}", null);
    }

    /** PKG_FARMACIA.PRO_DETALLE_RECETA(idReceta, OUT cursor). */
    public List<Map<String, Object>> detalleReceta(UsuarioSesion u, Long idReceta) {
        return consultarCursor(u, "{call PKG_FARMACIA.PRO_DETALLE_RECETA(?, ?)}", idReceta);
    }

    /**
     * Ejecuta un procedimiento de consulta: un parametro de entrada opcional (id) y, al final,
     * el SYS_REFCURSOR de salida. El cursor se lee dentro del bloque, antes de cerrar la sentencia.
     */
    private List<Map<String, Object>> consultarCursor(UsuarioSesion u, String llamada, Long id) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall(llamada)) {
                int posicionCursor = 1;
                if (id != null) {
                    cs.setLong(1, id);
                    posicionCursor = 2;
                }
                cs.registerOutParameter(posicionCursor, Types.REF_CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(posicionCursor)) {
                    return CursorMapper.aLista(rs);
                }
            }
        });
    }
}
