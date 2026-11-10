package co.edu.univalle.clinica.reportes;

import java.time.LocalDate;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.error.OperacionPendienteException;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Punto ÚNICO de integración con los procedimientos PL/SQL de reportes.
 * PENDIENTE (equipo PL/SQL): reemplazar el "throw" por la llamada al procedimiento.
 */
@Repository
public class ReportesRepository {

    private final ContextoOracle contexto;

    public ReportesRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    public Map<String, Object> resumen(UsuarioSesion u, LocalDate desde, LocalDate hasta) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: resumen del periodo (desde, hasta).
            throw new OperacionPendienteException("Reporte resumen");
        });
    }
}
