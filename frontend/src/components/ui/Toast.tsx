import { createContext, useCallback, useContext, useMemo, useRef, useState, type ReactNode } from 'react';
import { AlertTriangle, CheckCircle2, Info, Wrench, X } from 'lucide-react';

export type TipoToast = 'exito' | 'error' | 'info' | 'pendiente';

interface Toast {
  id: number;
  tipo: TipoToast;
  titulo: string;
  mensaje?: string;
}

interface ToastValue {
  mostrar: (t: Omit<Toast, 'id'>) => void;
}

const ToastContext = createContext<ToastValue | null>(null);

const ICONOS = { exito: CheckCircle2, error: AlertTriangle, info: Info, pendiente: Wrench };

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const siguiente = useRef(1);

  const cerrar = useCallback((id: number) => setToasts((ts) => ts.filter((t) => t.id !== id)), []);

  const mostrar = useCallback(
    (t: Omit<Toast, 'id'>) => {
      const id = siguiente.current++;
      setToasts((ts) => [...ts.slice(-3), { ...t, id }]);
      window.setTimeout(() => cerrar(id), t.tipo === 'exito' || t.tipo === 'info' ? 5000 : 9000);
    },
    [cerrar],
  );

  const valor = useMemo(() => ({ mostrar }), [mostrar]);

  return (
    <ToastContext.Provider value={valor}>
      {children}
      <div className="toasts" role="region" aria-live="polite" aria-label="Notificaciones">
        {toasts.map((t) => {
          const Icono = ICONOS[t.tipo];
          return (
            <div key={t.id} className={`toast toast--${t.tipo}`} role={t.tipo === 'error' ? 'alert' : 'status'}>
              <Icono size={20} className="toast__icono" aria-hidden />
              <div className="toast__texto">
                <strong>{t.titulo}</strong>
                {t.mensaje && <p>{t.mensaje}</p>}
              </div>
              <button className="toast__cerrar" onClick={() => cerrar(t.id)} aria-label="Cerrar notificación">
                <X size={16} />
              </button>
            </div>
          );
        })}
      </div>
    </ToastContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useToast(): ToastValue {
  const ctx = useContext(ToastContext);
  if (!ctx) throw new Error('useToast debe usarse dentro de ToastProvider');
  return ctx;
}
