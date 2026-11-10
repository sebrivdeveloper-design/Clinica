/** Formato de error que devuelve el backend. */
export interface ApiErrorBody {
  error: string;
  codigo: number | null;
}

/** Fila genérica devuelta por un cursor de Oracle (columnas en camelCase). */
export type Fila = Record<string, unknown>;

/** Respuesta genérica de una operación de escritura (lo que devuelva el procedimiento). */
export type ResultadoOperacion = Record<string, unknown> | null;
