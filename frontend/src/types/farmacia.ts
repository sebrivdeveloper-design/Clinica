/** Campos devueltos por PRO_LISTAR_MEDICAMENTOS (columnas de Oracle en camelCase). */
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

/** Respuesta de POST /api/recetas. */
export interface RecetaCreada {
  idReceta: number;
}

/** Respuesta de POST /api/recetas/{id}/detalle. */
export interface DetalleCreado {
  idDetalle: number;
}

/** Respuesta de POST /api/recetas/detalle/{id}/entrega: lo que dejo la entrega, segun Oracle. */
export interface EntregaResultado {
  cantidadPendiente: number;
  estadoDetalle: string;
  estadoReceta: string;
}

/** Fila de GET /api/recetas/detalles-pendientes (PRO_DETALLES_PENDIENTES). */
export interface DetallePendiente {
  idDetalle: number;
  idReceta: number;
  fechaEmision: string;
  paciente: string;
  documento: string;
  medicamento: string;
  cantidad: number;
  cantidadPendiente: number;
  dosis: string;
  stockDisponible: number | null;
  estado: string;
  [extra: string]: unknown;
}

/** Fila de GET /api/recetas/{id}/detalle (PRO_DETALLE_RECETA). */
export interface DetalleReceta {
  idDetalle: number;
  idMedicamento: number;
  medicamento: string;
  dosis: string;
  cantidad: number;
  cantidadEntregada: number;
  cantidadPendiente: number;
  estado: string;
  farmaceutico: string | null;
  fechaEntrega: string | null;
  [extra: string]: unknown;
}