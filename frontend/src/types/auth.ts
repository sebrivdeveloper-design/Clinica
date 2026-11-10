export const ROLES = ['ADMINISTRADOR', 'MEDICO', 'RECEPCIONISTA', 'FARMACEUTICO', 'PACIENTE'] as const;

export type Rol = (typeof ROLES)[number];

export interface LoginRequest {
  username: string;
  password: string;
}

export interface LoginResponse {
  token: string;
  rol: Rol;
  idEntidad: number | null;
}

/** Sesión activa en el navegador. Nunca contiene la contraseña. */
export interface Sesion {
  token: string;
  rol: Rol;
  idEntidad: number | null;
  username: string;
  /** Expiración del JWT en milisegundos (epoch). */
  expiraEn: number;
}

export const ETIQUETA_ROL: Record<Rol, string> = {
  ADMINISTRADOR: 'Administrador',
  MEDICO: 'Médico',
  RECEPCIONISTA: 'Recepcionista',
  FARMACEUTICO: 'Farmacéutico',
  PACIENTE: 'Paciente',
};
