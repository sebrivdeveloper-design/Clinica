import { http } from '../api/httpClient';
import type { ResultadoOperacion } from '../types/api';
import type { HistoriaClinica, HistoriaRequest } from '../types/historia';

/** Historias clínicas. Dependen de procedimientos PL/SQL pendientes (501 mientras tanto). */
export const historiaService = {
  /** GET /api/historias — Oracle filtra según el rol del usuario en sesión. */
  listar: (signal?: AbortSignal) => http.get<HistoriaClinica[]>('/api/historias', { signal }),

  /** POST /api/historias */
  registrar: (datos: HistoriaRequest) => http.post<ResultadoOperacion>('/api/historias', datos),
};
