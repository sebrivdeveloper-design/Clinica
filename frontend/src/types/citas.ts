/**
 * Tipos de citas y agenda. Los campos de respuesta siguen las columnas de
 * TBL_AGENDA_MEDICO / TBL_CITAS_MEDICAS en camelCase; se confirmarán cuando
 * el equipo defina los cursores de los procedimientos.
 */
export interface BloqueAgenda {
  idAgenda: number;
  idMedico?: number;
  fechaHoraInicio: string;
  fechaHoraFin: string;
  estado?: string;
  [extra: string]: unknown;
}

export interface ReservaCitaRequest {
  idPaciente: number;
  idAgenda: number;
  observacion?: string;
}

export interface CancelarCitaRequest {
  observacion?: string;
}

export interface CancelacionMasivaRequest {
  idMedico: number;
  desde: string; // yyyy-MM-dd
  hasta: string; // yyyy-MM-dd
  observacion?: string;
}

export interface MedicoResumen {
  idMedico: number;
  documento: string;
  nombre: string;
  especialidad: string;
  [extra: string]: unknown;
}

export interface PacienteResumen {
  idPaciente: number;
  documento: string;
  nombre: string;
  [extra: string]: unknown;
}

/** Cita del paciente (PRO_MIS_CITAS). */
export interface CitaPaciente {
  idCita: number;
  idAgenda: number;
  fechaHoraInicio: string;
  fechaHoraFin: string;
  idMedico: number;
  medico: string;
  especialidad: string;
  estado: string;
  puedeCancelar: 'S' | 'N';
  [extra: string]: unknown;
}