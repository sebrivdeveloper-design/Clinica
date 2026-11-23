import { http } from '../api/httpClient';
import type {
  DetalleCreado,
  DetallePendiente,
  DetalleReceta,
  DetalleRecetaRequest,
  EntregaRequest,
  EntregaResultado,
  Medicamento,
  RecetaCreada,
  RecetaRequest,
} from '../types/farmacia';

/** Recetas, detalles, entregas y medicamentos (PKG_FARMACIA). */
export const farmaciaService = {
  /** GET /api/medicamentos */
  medicamentos: (signal?: AbortSignal) => http.get<Medicamento[]>('/api/medicamentos', { signal }),

  /** GET /api/recetas/detalles-pendientes — medicamentos con cantidad por entregar (FARMACEUTICO). */
  detallesPendientes: (signal?: AbortSignal) => http.get<DetallePendiente[]>('/api/recetas/detalles-pendientes', { signal }),

  /** GET /api/recetas/{id}/detalle — medicamentos de una receta y su avance de entrega. */
  detalleReceta: (idReceta: number, signal?: AbortSignal) =>
    http.get<DetalleReceta[]>(`/api/recetas/${idReceta}/detalle`, { signal }),

  /** POST /api/recetas */
  crearReceta: (datos: RecetaRequest) => http.post<RecetaCreada>('/api/recetas', datos),

  /** POST /api/recetas/{id}/detalle */
  agregarDetalle: (idReceta: number, datos: DetalleRecetaRequest) =>
    http.post<DetalleCreado>(`/api/recetas/${idReceta}/detalle`, datos),

  /** POST /api/recetas/detalle/{id}/entrega — Oracle descuenta el stock y deduce los estados. */
  registrarEntrega: (idDetalle: number, datos: EntregaRequest) =>
    http.post<EntregaResultado>(`/api/recetas/detalle/${idDetalle}/entrega`, datos),
};