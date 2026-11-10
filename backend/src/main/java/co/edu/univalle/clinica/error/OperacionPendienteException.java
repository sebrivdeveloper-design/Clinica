package co.edu.univalle.clinica.error;

/**
 * Indica que el endpoint existe pero el procedimiento PL/SQL que debe ejecutar
 * todavía no ha sido implementado por el equipo. Se responde con HTTP 501.
 */
public class OperacionPendienteException extends RuntimeException {

    public OperacionPendienteException(String operacion) {
        super("Operación pendiente: \"" + operacion
                + "\" requiere un procedimiento PL/SQL que aún no está implementado en Oracle.");
    }
}
