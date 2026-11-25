package co.edu.univalle.clinica.citas;

import java.sql.CallableStatement;
import java.sql.ResultSet;
import java.sql.Timestamp;
import java.sql.Types;
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
 * HU01 conectada: agendaDisponible, reservar y misCitas (PKG_CITAS).
 * HU02 conectada: cancelar (PKG_CITAS.PRO_CANCELAR_CITA).
 * PENDIENTE (HU09): cancelacionMasiva.
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

    /** PKG_CITAS.PRO_RESERVAR_CITA(idPaciente, idAgenda, horaInicio, OUT idCita). El COMMIT lo hace Oracle. La observación no se guarda al reservar. */
    public Map<String, Object> reservar(UsuarioSesion u, ReservaCitaRequest req) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_RESERVAR_CITA(?, ?, ?, ?)}")) {
                cs.setLong(1, req.idPaciente());
                cs.setLong(2, req.idAgenda());
                if (req.horaInicio() == null) {
                    cs.setNull(3, Types.TIMESTAMP);
                } else {
                    cs.setTimestamp(3, Timestamp.valueOf(req.horaInicio()));
                }
                cs.registerOutParameter(4, Types.NUMERIC);
                cs.execute();
                return Map.of("idCita", cs.getLong(4));
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

    /**
     * PKG_CITAS.PRO_CANCELAR_CITA(idCita, motivo) (HU02). Oracle valida permisos, que la cita esté
     * Pendiente y que el motivo no esté vacío; el origen (Paciente/Clinica) lo deduce del rol.
     * El COMMIT lo hace Oracle.
     */
    public Map<String, Object> cancelar(UsuarioSesion u, Long idCita, String observacion) {
        return contexto.ejecutar(u, con -> {
            try (CallableStatement cs = con.prepareCall("{call PKG_CITAS.PRO_CANCELAR_CITA(?, ?)}")) {
                cs.setLong(1, idCita);
                if (observacion == null) {
                    cs.setNull(2, Types.VARCHAR);
                } else {
                    cs.setString(2, observacion);
                }
                cs.execute();
                return Map.of("idCita", idCita);
            }
        });
    }

    public Map<String, Object> cancelacionMasiva(UsuarioSesion u, CancelacionMasivaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente (HU09): cancelación masiva (idMedico, desde, hasta, observacion) -> cantidad.
            throw new OperacionPendienteException("Cancelación masiva de citas");
        });
    }
}