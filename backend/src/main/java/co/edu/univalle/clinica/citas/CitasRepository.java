package co.edu.univalle.clinica.citas;

import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.sql.Date;
import java.sql.Types;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.citas.CitasController.CancelacionMasivaRequest;
import co.edu.univalle.clinica.citas.CitasController.ReservaCitaRequest;
import co.edu.univalle.clinica.error.OperacionPendienteException;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.oracle.CursorMapper;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;
import oracle.jdbc.OracleTypes;

/**
 * Punto ÚNICO de integración con los procedimientos PL/SQL de citas.
 * El contexto del usuario ya queda establecido (PKG_CONTEXTO) dentro de cada bloque.
 *
 * HU01 conectada: agendaDisponible, reservar, citasDelMedico y misCitas (PKG_CITAS).
 * PENDIENTE (HU02 y HU09): cancelar y cancelacionMasiva.
 */
@Repository
public class CitasRepository {

    private final ContextoOracle contexto;

    public CitasRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    /** PKG_CITAS.PRO_AGENDA_DISPONIBLE(idMedico, OUT cursor) */
    public List<Map<String, Object>> agendaDisponible(UsuarioSesion u, Long idMedico) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_AGENDA_DISPONIBLE(?, ?)}")) {
                cs.setLong(1, idMedico);
                cs.registerOutParameter(2, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(2)) {
                    return CursorMapper.aLista(rs);
                }
            }
        });
    }

    /** PKG_CITAS.PRO_RESERVAR_CITA(idPaciente, idAgenda, observacion, OUT idCita). El COMMIT lo hace Oracle. */
    public Map<String, Object> reservar(UsuarioSesion u, ReservaCitaRequest req) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_RESERVAR_CITA(?, ?, ?, ?)}")) {
                cs.setLong(1, req.idPaciente());
                cs.setLong(2, req.idAgenda());
                if (req.observacion() == null || req.observacion().isBlank()) {
                    cs.setNull(3, Types.VARCHAR);
                } else {
                    cs.setString(3, req.observacion().trim());
                }
                cs.registerOutParameter(4, Types.NUMERIC);
                cs.execute();
                return Map.of("idCita", cs.getLong(4));
            }
        });
    }

    /** PKG_CITAS.PRO_CITAS_MEDICO(fecha, OUT cursor): citas pendientes del medico en sesion. */
    public List<Map<String, Object>> citasDelMedico(UsuarioSesion u, LocalDate fecha) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_CITAS_MEDICO(?, ?)}")) {
                if (fecha == null) {
                    cs.setNull(1, Types.DATE);
                } else {
                    cs.setDate(1, Date.valueOf(fecha));
                }
                cs.registerOutParameter(2, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(2)) {
                    return CursorMapper.aLista(rs);
                }
            }
        });
    }

    /** PKG_CITAS.PRO_MIS_CITAS(idPaciente, OUT cursor). El paciente solo ve las suyas (lo impone Oracle). */
    public List<Map<String, Object>> misCitas(UsuarioSesion u, Long idPaciente) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_MIS_CITAS(?, ?)}")) {
                if (idPaciente == null) {
                    cs.setNull(1, Types.NUMERIC);
                } else {
                    cs.setLong(1, idPaciente);
                }
                cs.registerOutParameter(2, OracleTypes.CURSOR);
                cs.execute();
                try (ResultSet rs = (ResultSet) cs.getObject(2)) {
                    return CursorMapper.aLista(rs);
                }
            }
        });
    }

    public Map<String, Object> cancelar(UsuarioSesion u, Long idCita, String observacion) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente (HU02): cancelar cita (idCita, observacion).
            throw new OperacionPendienteException("Cancelar cita");
        });
    }

    public Map<String, Object> cancelacionMasiva(UsuarioSesion u, CancelacionMasivaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente (HU09): cancelación masiva (idMedico, desde, hasta, observacion) -> cantidad.
            throw new OperacionPendienteException("Cancelación masiva de citas");
        });
    }
}