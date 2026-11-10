package co.edu.univalle.clinica.historias;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.error.OperacionPendienteException;
import co.edu.univalle.clinica.historias.HistoriasController.HistoriaRequest;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Punto ÚNICO de integración con los procedimientos PL/SQL de historias clínicas.
 * PENDIENTE (equipo PL/SQL): reemplazar cada "throw" por la llamada al procedimiento.
 */
@Repository
public class HistoriasRepository {

    private final ContextoOracle contexto;

    public HistoriasRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    public Map<String, Object> registrar(UsuarioSesion u, HistoriaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: registrar consulta (idCita, diagnostico, notasMedicas) -> id de la historia.
            throw new OperacionPendienteException("Registrar historia clínica");
        });
    }

    public List<Map<String, Object>> listar(UsuarioSesion u) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: consultar historias visibles para el usuario (SYS_REFCURSOR -> CursorMapper).
            throw new OperacionPendienteException("Consultar historias clínicas");
        });
    }
}
