import type { Sesion } from '../types/auth';

/**
 * Guarda la sesión (JWT + datos públicos del usuario) en sessionStorage:
 * se borra al cerrar la pestaña. Nunca se guarda la contraseña.
 */
const CLAVE = 'clinica.sesion';

export const tokenStorage = {
  leer(): Sesion | null {
    try {
      const raw = sessionStorage.getItem(CLAVE);
      return raw ? (JSON.parse(raw) as Sesion) : null;
    } catch {
      return null;
    }
  },
  guardar(sesion: Sesion): void {
    try {
      sessionStorage.setItem(CLAVE, JSON.stringify(sesion));
    } catch {
      /* almacenamiento no disponible: la sesión vive solo en memoria */
    }
  },
  borrar(): void {
    try {
      sessionStorage.removeItem(CLAVE);
    } catch {
      /* nada que borrar */
    }
  },
  token(): string | null {
    return this.leer()?.token ?? null;
  },
};
