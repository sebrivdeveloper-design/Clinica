import type { ReactNode } from 'react';
import { AlertTriangle, Inbox, RefreshCw, WifiOff, Wrench } from 'lucide-react';
import type { ApiError } from '../../api/apiError';
import { describirError } from '../../api/errorMessages';

export function Spinner({ pequeno, etiqueta }: { pequeno?: boolean; etiqueta?: string }) {
  return (
    <span className={`spinner${pequeno ? ' spinner--sm' : ''}`} role="status" aria-label={etiqueta ?? 'Cargando'} />
  );
}

export function Cargando({ texto = 'Cargando información…' }: { texto?: string }) {
  return (
    <div className="estado">
      <Spinner />
      <p className="estado__texto">{texto}</p>
    </div>
  );
}

export function EstadoVacio({ titulo, texto, accion }: { titulo: string; texto?: string; accion?: ReactNode }) {
  return (
    <div className="estado">
      <div className="estado__icono">
        <Inbox size={28} aria-hidden />
      </div>
      <h3>{titulo}</h3>
      {texto && <p className="estado__texto">{texto}</p>}
      {accion}
    </div>
  );
}

/** Se muestra cuando el backend responde 501: el procedimiento PL/SQL aún no existe. */
export function AvisoPendiente({ mensaje, compacto }: { mensaje?: string; compacto?: boolean }) {
  return (
    <div className={`aviso aviso--pendiente${compacto ? ' aviso--compacto' : ''}`} role="status">
      <Wrench size={20} aria-hidden />
      <div>
        <strong>Pendiente de integración con Oracle</strong>
        <p>
          {mensaje ??
            'El endpoint está conectado, pero el procedimiento PL/SQL que lo respalda aún no ha sido implementado por el equipo.'}
        </p>
      </div>
    </div>
  );
}

export function EstadoError({ error, alReintentar }: { error: ApiError; alReintentar?: () => void }) {
  if (error.pendiente) return <AvisoPendiente mensaje={error.message} />;
  const { titulo, detalle } = describirError(error);
  const Icono = error.sinConexion ? WifiOff : AlertTriangle;
  return (
    <div className="estado estado--error" role="alert">
      <div className="estado__icono">
        <Icono size={28} aria-hidden />
      </div>
      <h3>{titulo}</h3>
      {detalle && <p className="estado__texto">{detalle}</p>}
      {alReintentar && (
        <button className="btn btn--secundario" onClick={alReintentar}>
          <RefreshCw size={16} aria-hidden />
          <span>Reintentar</span>
        </button>
      )}
    </div>
  );
}

interface EstadoConsultaProps<T> {
  cargando: boolean;
  error: ApiError | null;
  datos: T | null;
  vacio?: (datos: T) => boolean;
  textoVacio?: string;
  alReintentar?: () => void;
  children: (datos: T) => ReactNode;
}

/** Resuelve en un solo lugar los estados de carga, error, pendiente, vacío y datos. */
export function EstadoConsulta<T>({
  cargando,
  error,
  datos,
  vacio,
  textoVacio = 'No hay resultados para mostrar.',
  alReintentar,
  children,
}: EstadoConsultaProps<T>) {
  if (cargando) return <Cargando />;
  if (error) return <EstadoError error={error} alReintentar={alReintentar} />;
  if (datos == null) return null;
  const estaVacio = vacio ? vacio(datos) : Array.isArray(datos) && datos.length === 0;
  if (estaVacio) return <EstadoVacio titulo="Sin resultados" texto={textoVacio} />;
  return <>{children(datos)}</>;
}
