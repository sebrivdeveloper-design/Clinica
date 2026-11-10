/** Error normalizado de cualquier llamada a la API. */
export class ApiError extends Error {
  readonly status: number;
  readonly codigo: number | null;

  constructor(status: number, codigo: number | null, message: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.codigo = codigo;
  }

  /** El endpoint existe pero su procedimiento PL/SQL aún no está implementado (HTTP 501). */
  get pendiente(): boolean {
    return this.status === 501;
  }

  /** No hubo respuesta del servidor (backend apagado, red, CORS). */
  get sinConexion(): boolean {
    return this.status === 0;
  }
}

export function aApiError(e: unknown): ApiError {
  if (e instanceof ApiError) return e;
  return new ApiError(-1, null, e instanceof Error ? e.message : 'Error inesperado');
}
