import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';
import { registrarManejadorNoAutorizado } from '../api/httpClient';
import { authService } from '../services/authService';
import type { Rol, Sesion } from '../types/auth';
import { leerClaims } from './jwt';
import { tokenStorage } from './tokenStorage';

const MENSAJE_EXPIRADA = 'Su sesión expiró. Inicie sesión nuevamente.';

interface AuthValue {
  sesion: Sesion | null;
  /** Mensaje a mostrar en el login cuando la sesión terminó por expiración. */
  avisoCierre: string | null;
  iniciarSesion: (username: string, password: string) => Promise<Sesion>;
  cerrarSesion: (motivo?: string) => void;
  tieneRol: (...roles: Rol[]) => boolean;
}

const AuthContext = createContext<AuthValue | null>(null);

function sesionInicial(): { sesion: Sesion | null; aviso: string | null } {
  const guardada = tokenStorage.leer();
  if (!guardada) return { sesion: null, aviso: null };
  if (guardada.expiraEn <= Date.now()) {
    tokenStorage.borrar();
    return { sesion: null, aviso: MENSAJE_EXPIRADA };
  }
  return { sesion: guardada, aviso: null };
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [inicial] = useState(sesionInicial);
  const [sesion, setSesion] = useState<Sesion | null>(inicial.sesion);
  const [avisoCierre, setAvisoCierre] = useState<string | null>(inicial.aviso);

  const cerrarSesion = useCallback((motivo?: string) => {
    tokenStorage.borrar();
    setSesion(null);
    setAvisoCierre(motivo ?? null);
  }, []);

  // El backend respondió 401 a una petición autenticada: token vencido o inválido.
  useEffect(() => {
    registrarManejadorNoAutorizado(() => cerrarSesion(MENSAJE_EXPIRADA));
    return () => registrarManejadorNoAutorizado(null);
  }, [cerrarSesion]);

  // Cierre automático al llegar la hora de expiración del JWT.
  useEffect(() => {
    if (!sesion) return;
    const t = window.setTimeout(() => cerrarSesion(MENSAJE_EXPIRADA), Math.max(sesion.expiraEn - Date.now(), 0));
    return () => window.clearTimeout(t);
  }, [sesion, cerrarSesion]);

  const iniciarSesion = useCallback(async (username: string, password: string) => {
    const r = await authService.login({ username, password });
    const claims = leerClaims(r.token);
    const nueva: Sesion = {
      token: r.token,
      rol: r.rol,
      idEntidad: r.idEntidad ?? null,
      username: claims.username ?? username,
      expiraEn: (claims.exp ?? 0) * 1000,
    };
    tokenStorage.guardar(nueva);
    setAvisoCierre(null);
    setSesion(nueva);
    return nueva;
  }, []);

  const tieneRol = useCallback((...roles: Rol[]) => !!sesion && roles.includes(sesion.rol), [sesion]);

  const valor = useMemo(
    () => ({ sesion, avisoCierre, iniciarSesion, cerrarSesion, tieneRol }),
    [sesion, avisoCierre, iniciarSesion, cerrarSesion, tieneRol],
  );
  return <AuthContext.Provider value={valor}>{children}</AuthContext.Provider>;
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth debe usarse dentro de AuthProvider');
  return ctx;
}

/** Atajo para páginas que ya están protegidas: la sesión siempre existe. */
// eslint-disable-next-line react-refresh/only-export-components
export function useSesion(): Sesion {
  const { sesion } = useAuth();
  if (!sesion) throw new Error('Se requiere sesión activa');
  return sesion;
}
