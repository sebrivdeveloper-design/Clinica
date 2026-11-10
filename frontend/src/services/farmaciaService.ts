import { http } from '../api/httpClient';
import type { ResultadoOperacion } from '../types/api';
import type { DetalleRecetaRequest, EntregaRequest, Medicamento, RecetaRequest } from '../types/farmacia';

/** Recetas, detalles, entregas y medicamentos. Dependen de procedimientos PL/SQL pendientes. */
export const farmaciaService = {
  /** GET /api/medicamentos */
  medicamentos: (signal?: AbortSignal) => http.get<Medicamento[]>('/api/medicamentos', { signal }),

  /** POST /api/recetas */
  crearReceta: (datos: RecetaRequest) => http.post<ResultadoOperacion>('/api/recetas', datos),

  /** POST /api/recetas/{id}/detalle */
  agregarDetalle: (idReceta: number, datos: DetalleRecetaRequest) =>
    http.post<ResultadoOperacion>(`/api/recetas/${idReceta}/detalle`, datos),

  /** POST /api/recetas/detalle/{id}/entrega — Oracle descuenta el stock. */
  registrarEntrega: (idDetalle: number, datos: EntregaRequest) =>
    http.post<ResultadoOperacion>(`/api/recetas/detalle/${idDetalle}/entrega`, datos),
};
