package co.edu.univalle.clinica.error;

/** Formato único de error de la API: {"error": "...", "codigo": 20001}. */
public record ApiError(String error, Integer codigo) {
}
