import { useCallback, useState } from 'react';
import { aApiError, type ApiError } from '../api/apiError';
import { describirError } from '../api/errorMessages';
import { useToast } from '../components/ui/Toast';

export type ResultadoEnvio<R> = { ok: true; datos: R } | { ok: false; error: ApiError };

/**
 * Envía una operación de escritura y notifica errores automáticamente.
 * El mensaje de éxito lo decide la página, solo cuando el servidor confirma.
 */
export function useEnvio<A extends unknown[], R>(fn: (...args: A) => Promise<R>) {
  const toast = useToast();
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<ApiError | null>(null);

  const ejecutar = useCallback(
    async (...args: A): Promise<ResultadoEnvio<R>> => {
      setEnviando(true);
      setError(null);
      try {
        const datos = await fn(...args);
        return { ok: true, datos };
      } catch (e) {
        const err = aApiError(e);
        setError(err);
        if (err.pendiente) {
          toast.mostrar({ tipo: 'pendiente', titulo: 'Pendiente de PL/SQL', mensaje: err.message });
        } else if (err.status !== 401) {
          const { titulo, detalle } = describirError(err);
          toast.mostrar({ tipo: 'error', titulo, mensaje: detalle });
        }
        return { ok: false, error: err };
      } finally {
        setEnviando(false);
      }
    },
    [fn, toast],
  );

  return { ejecutar, enviando, error, limpiarError: () => setError(null) };
}
