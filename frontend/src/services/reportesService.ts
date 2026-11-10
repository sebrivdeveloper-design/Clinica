import { http } from '../api/httpClient';
import type { ResumenReporte } from '../types/reportes';

/** Reportes. Depende de un procedimiento PL/SQL pendiente (501 mientras tanto). */
export const reportesService = {
  /** GET /api/reportes/resumen?desde=&hasta= (fechas yyyy-MM-dd) */
  resumen: (desde: string, hasta: string, signal?: AbortSignal) =>
    http.get<ResumenReporte>('/api/reportes/resumen', { query: { desde, hasta }, signal }),
};
