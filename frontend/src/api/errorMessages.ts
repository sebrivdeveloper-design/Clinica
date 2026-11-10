import type { ApiError } from './apiError';

/** Títulos comprensibles para los códigos de error que lanza Oracle. */
const POR_CODIGO: Record<number, string> = {
  20001: 'El médico ya tiene ocupado ese horario',
  20002: 'No se encontró el registro solicitado',
  20003: 'La cita no está en un estado válido para esta operación',
  20004: 'No hay stock suficiente del medicamento',
  20005: 'No tiene permiso para realizar esta operación',
  20006: 'Usuario o contraseña incorrectos',
  20007: 'Aún faltan medicamentos por entregar',
};

const POR_ESTADO: Record<number, string> = {
  0: 'No fue posible conectar con el servidor',
  400: 'Revise los datos enviados',
  401: 'Su sesión no es válida o expiró',
  403: 'No tiene permiso para realizar esta operación',
  404: 'Recurso no encontrado',
  501: 'Funcionalidad pendiente de implementación en Oracle',
  503: 'La base de datos no está disponible',
};

export interface MensajeError {
  titulo: string;
  detalle?: string;
}

/** Título amigable + detalle original del servidor (si aporta información). */
export function describirError(err: ApiError): MensajeError {
  const titulo =
    (err.codigo != null ? POR_CODIGO[err.codigo] : undefined) ??
    POR_ESTADO[err.status] ??
    (err.status >= 500 ? 'Ocurrió un error en el servidor' : 'No se pudo completar la operación');
  const detalle = err.message && err.message !== titulo ? err.message : undefined;
  return { titulo, detalle };
}
