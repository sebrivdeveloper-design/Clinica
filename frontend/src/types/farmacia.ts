/** Campos según TBL_MEDICAMENTOS / TBL_STOCK_FARMACIA en camelCase (a confirmar). */
export interface Medicamento {
  idMedicamento: number;
  nombre: string;
  descripcion?: string | null;
  presentacion?: string;
  cantidadDisponible?: number;
  cantidadMinima?: number;
  [extra: string]: unknown;
}

export interface RecetaRequest {
  idHistoria: number;
}

export interface DetalleRecetaRequest {
  idMedicamento: number;
  cantidad: number;
  dosis: string;
}

export interface EntregaRequest {
  cantidad: number;
}
