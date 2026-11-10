/** Campos según TBL_HISTORIA_CLINICA en camelCase (a confirmar con el procedimiento). */
export interface HistoriaClinica {
  idHistoria: number;
  idCita: number;
  diagnostico: string;
  notasMedicas?: string | null;
  fechaAtencion: string;
  [extra: string]: unknown;
}

export interface HistoriaRequest {
  idCita: number;
  diagnostico: string;
  notasMedicas?: string;
}
