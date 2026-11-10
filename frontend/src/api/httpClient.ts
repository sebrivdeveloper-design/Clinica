import { env } from '../config/env';
import { tokenStorage } from '../auth/tokenStorage';
import type { ApiErrorBody } from '../types/api';
import { ApiError } from './apiError';

type Metodo = 'GET' | 'POST' | 'PUT' | 'DELETE';
type ValorQuery = string | number | undefined | null;

export interface OpcionesPeticion {
  query?: Record<string, ValorQuery>;
  body?: unknown;
  /** false para endpoints públicos (login). Por defecto se envía el Bearer token. */
  auth?: boolean;
  signal?: AbortSignal;
}

let alNoAutorizado: (() => void) | null = null;

/** Lo registra AuthContext para cerrar la sesión cuando el backend responde 401. */
export function registrarManejadorNoAutorizado(fn: (() => void) | null): void {
  alNoAutorizado = fn;
}

function construirUrl(ruta: string, query?: Record<string, ValorQuery>): string {
  const url = new URL(env.apiBaseUrl + ruta);
  if (query) {
    for (const [k, v] of Object.entries(query)) {
      if (v !== undefined && v !== null && v !== '') url.searchParams.set(k, String(v));
    }
  }
  return url.toString();
}

function parsear(texto: string): unknown {
  try {
    return JSON.parse(texto);
  } catch {
    return null;
  }
}

async function peticion<T>(metodo: Metodo, ruta: string, op: OpcionesPeticion = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' };
  if (op.body !== undefined) headers['Content-Type'] = 'application/json';
  const usaAuth = op.auth !== false;
  if (usaAuth) {
    const token = tokenStorage.token();
    if (token) headers.Authorization = `Bearer ${token}`;
  }

  let res: Response;
  try {
    res = await fetch(construirUrl(ruta, op.query), {
      method: metodo,
      headers,
      body: op.body !== undefined ? JSON.stringify(op.body) : undefined,
      signal: op.signal,
    });
  } catch (e) {
    if (e instanceof DOMException && e.name === 'AbortError') throw e;
    throw new ApiError(0, null, `No hay respuesta del backend en ${env.apiBaseUrl}. Verifique que esté en ejecución.`);
  }

  const texto = await res.text();
  const datos = texto ? parsear(texto) : null;

  if (!res.ok) {
    const cuerpo = datos as Partial<ApiErrorBody> | null;
    const error = new ApiError(res.status, cuerpo?.codigo ?? null, cuerpo?.error ?? `Error HTTP ${res.status}`);
    if (res.status === 401 && usaAuth) alNoAutorizado?.();
    throw error;
  }
  return datos as T;
}

export const http = {
  get: <T>(ruta: string, op?: Omit<OpcionesPeticion, 'body'>) => peticion<T>('GET', ruta, op),
  post: <T>(ruta: string, body?: unknown, op?: OpcionesPeticion) => peticion<T>('POST', ruta, { ...op, body }),
  put: <T>(ruta: string, body?: unknown, op?: OpcionesPeticion) => peticion<T>('PUT', ruta, { ...op, body }),
};
