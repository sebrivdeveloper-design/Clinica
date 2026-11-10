package co.edu.univalle.clinica.farmacia;

import java.util.List;
import java.util.Map;

import org.springframework.stereotype.Repository;

import co.edu.univalle.clinica.error.OperacionPendienteException;
import co.edu.univalle.clinica.farmacia.FarmaciaController.DetalleRequest;
import co.edu.univalle.clinica.farmacia.FarmaciaController.EntregaRequest;
import co.edu.univalle.clinica.farmacia.FarmaciaController.RecetaRequest;
import co.edu.univalle.clinica.oracle.ContextoOracle;
import co.edu.univalle.clinica.seguridad.UsuarioSesion;

/**
 * Punto ÚNICO de integración con los procedimientos PL/SQL de farmacia.
 * PENDIENTE (equipo PL/SQL): reemplazar cada "throw" por la llamada al procedimiento.
 */
@Repository
public class FarmaciaRepository {

    private final ContextoOracle contexto;

    public FarmaciaRepository(ContextoOracle contexto) {
        this.contexto = contexto;
    }

    public Map<String, Object> crearReceta(UsuarioSesion u, RecetaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: crear receta (idHistoria) -> id de la receta.
            throw new OperacionPendienteException("Crear receta médica");
        });
    }

    public Map<String, Object> agregarDetalle(UsuarioSesion u, Long idReceta, DetalleRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: agregar detalle (idReceta, idMedicamento, cantidad, dosis) -> id del detalle.
            throw new OperacionPendienteException("Agregar detalle de receta");
        });
    }

    public Map<String, Object> registrarEntrega(UsuarioSesion u, Long idDetalle, EntregaRequest req) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: registrar entrega (idDetalle, cantidad); Oracle descuenta stock.
            throw new OperacionPendienteException("Registrar entrega de medicamento");
        });
    }

    public List<Map<String, Object>> medicamentos(UsuarioSesion u) {
        return contexto.ejecutar(u, con -> {
            // Procedimiento pendiente: consultar medicamentos con stock (SYS_REFCURSOR -> CursorMapper).
            throw new OperacionPendienteException("Consultar medicamentos");
        });
    }
}
