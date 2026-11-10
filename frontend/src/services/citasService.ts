import { http } from '../api/httpClient';
import type { ResultadoOperacion } from '../types/api';
import type {
  BloqueAgenda,
  CancelacionMasivaRequest,
  CancelarCitaRequest,
  ReservaCitaRequest,
} from '../types/citas';

/**
 * Citas y agenda. Todos dependen de procedimientos PL/SQL pendientes:
 * mientras no existan, el backend responde 501 y la interfaz lo muestra.
 */
export const citasService = {
  /** GET /api/agenda/disponible?idMedico= */
  agendaDisponible: (idMedico: number, signal?: AbortSignal) =>
    http.get<BloqueAgenda[]>('/api/agenda/disponible', { query: { idMedico }, signal }),

  /** POST /api/citas */
  reservar: (datos: ReservaCitaRequest) => http.post<ResultadoOperacion>('/api/citas', datos),

  /** PUT /api/citas/{id}/cancelar */
  cancelar: (idCita: number, datos: CancelarCitaRequest) =>
    http.put<ResultadoOperacion>(`/api/citas/${idCita}/cancelar`, datos),

  /** POST /api/citas/cancelacion-masiva */
  cancelacionMasiva: (datos: CancelacionMasivaRequest) =>
    http.post<ResultadoOperacion>('/api/citas/cancelacion-masiva', datos),
};
