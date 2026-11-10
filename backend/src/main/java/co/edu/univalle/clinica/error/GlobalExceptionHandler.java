package co.edu.univalle.clinica.error;

import java.sql.SQLException;
import java.util.stream.Collectors;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

/**
 * Traduce errores a {"error","codigo"}. Los errores de negocio vienen de Oracle
 * (RAISE_APPLICATION_ERROR -20001..-20999); aquí solo se elige el código HTTP.
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(OperacionPendienteException.class)
    ResponseEntity<ApiError> pendiente(OperacionPendienteException ex) {
        return ResponseEntity.status(HttpStatus.NOT_IMPLEMENTED).body(new ApiError(ex.getMessage(), null));
    }

    @ExceptionHandler(CannotGetJdbcConnectionException.class)
    ResponseEntity<ApiError> sinConexion(CannotGetJdbcConnectionException ex) {
        log.error("No fue posible conectar con Oracle", ex);
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE)
                .body(new ApiError("No fue posible conectar con la base de datos Oracle.", null));
    }

    @ExceptionHandler(DataAccessException.class)
    ResponseEntity<ApiError> oracle(DataAccessException ex) {
        SQLException sql = buscarSqlException(ex);
        if (sql != null && sql.getErrorCode() >= 20000 && sql.getErrorCode() <= 20999) {
            int codigo = sql.getErrorCode();
            return ResponseEntity.status(estadoPara(codigo)).body(new ApiError(mensajeOracle(sql), codigo));
        }
        log.error("Error de base de datos no controlado", ex);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                .body(new ApiError("Error al procesar la operación en la base de datos.", null));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<ApiError> validacion(MethodArgumentNotValidException ex) {
        String detalle = ex.getBindingResult().getFieldErrors().stream()
                .map(f -> f.getField() + ": " + f.getDefaultMessage())
                .collect(Collectors.joining("; "));
        return ResponseEntity.badRequest().body(new ApiError("Datos incompletos o inválidos. " + detalle, null));
    }

    @ExceptionHandler({ HttpMessageNotReadableException.class, MissingServletRequestParameterException.class,
            MethodArgumentTypeMismatchException.class })
    ResponseEntity<ApiError> peticionInvalida(Exception ex) {
        return ResponseEntity.badRequest().body(new ApiError("La solicitud no tiene el formato esperado.", null));
    }

    @ExceptionHandler(NoResourceFoundException.class)
    ResponseEntity<ApiError> noEncontrado(NoResourceFoundException ex) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(new ApiError("Recurso no encontrado.", null));
    }

    private static HttpStatus estadoPara(int codigo) {
        return switch (codigo) {
            case 20006 -> HttpStatus.UNAUTHORIZED;          // Credenciales inválidas
            case 20005 -> HttpStatus.FORBIDDEN;             // Sin permiso
            case 20002 -> HttpStatus.NOT_FOUND;             // Registro no encontrado
            case 20001, 20003, 20004, 20007 -> HttpStatus.CONFLICT;
            default -> HttpStatus.UNPROCESSABLE_CONTENT;
        };
    }

    private static SQLException buscarSqlException(Throwable t) {
        while (t != null) {
            if (t instanceof SQLException s) {
                return s;
            }
            t = t.getCause();
        }
        return null;
    }

    /** "ORA-20006: Credenciales invalidas\nORA-06512: ..." -> "Credenciales invalidas" */
    private static String mensajeOracle(SQLException ex) {
        String msg = ex.getMessage() == null ? "" : ex.getMessage();
        String primera = msg.lines().findFirst().orElse(msg);
        int i = primera.indexOf(": ");
        return (i >= 0 ? primera.substring(i + 2) : primera).trim();
    }
}
