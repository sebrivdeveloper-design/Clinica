package co.edu.univalle.clinica.citas;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.citas.CitasController.CancelacionMasivaRequest;
import co.edu.univalle.clinica.citas.CitasController.ReservaCitaRequest;
import co.edu.univalle.clinica.error.OperacionPendienteException;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Punto ÚNICO de integración con los procedimientos PL/SQL de citas.
 * El contexto del usuario ya queda establecido (PKG_CONTEXTO) dentro de cada bloque.
 * PENDIENTE (equipo PL/SQL): reemplazar cada "throw" por la llamada al procedimiento.
 */
@Repository
public class CitasRepository {

    private final ContextoOracle contexto;

    public CitasRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    public List<Map<String, Object>> agendaDisponible(UsuarioSesion u, Long idMedico) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: consultar bloques libres del médico (SYS_REFCURSOR -> CursorMapper).
            throw new OperacionPendienteException("Consultar agenda disponible");
        });
    }

    public Map<String, Object> reservar(UsuarioSesion u, ReservaCitaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: reservar cita (idPaciente, idAgenda, observacion) -> id de la cita.
            throw new OperacionPendienteException("Reservar cita");
        });
    }

    public Map<String, Object> cancelar(UsuarioSesion u, Long idCita, String observacion) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: cancelar cita (idCita, observacion).
            throw new OperacionPendienteException("Cancelar cita");
        });
    }

    public Map<String, Object> cancelacionMasiva(UsuarioSesion u, CancelacionMasivaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: cancelación masiva (idMedico, desde, hasta, observacion) -> cantidad.
            throw new OperacionPendienteException("Cancelación masiva de citas");
        });
    }
}
