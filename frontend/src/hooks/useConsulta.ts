import { useEffect, useState } from 'react';
import { aApiError, type ApiError } from '../api/apiError';

interface EstadoConsulta<T> {
  datos: T | null;
  error: ApiError | null;
  cargando: boolean;
}

/**
 * Ejecuta una consulta (GET) al montar y cuando cambian las dependencias.
 * Pasar fn = null deja la consulta en espera (por ejemplo, hasta que haya filtros).
 */
export function useConsulta<T>(fn: ((signal: AbortSignal) => Promise<T>) | null, deps: unknown[]) {
  const [estado, setEstado] = useState<EstadoConsulta<T>>({ datos: null, error: null, cargando: fn !== null });
  const [version, setVersion] = useState(0);

  useEffect(() => {
    if (!fn) {
      setEstado({ datos: null, error: null, cargando: false });
      return;
    }
    const ac = new AbortController();
    setEstado((s) => ({ ...s, cargando: true, error: null }));
    fn(ac.signal)
      .then((datos) => {
        if (!ac.signal.aborted) setEstado({ datos, error: null, cargando: false });
      })
      .catch((e: unknown) => {
        if (ac.signal.aborted) return;
        setEstado({ datos: null, error: aApiError(e), cargando: false });
      });
    return () => ac.abort();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [...deps, version]);

  return { ...estado, recargar: () => setVersion((v) => v + 1) };
}
