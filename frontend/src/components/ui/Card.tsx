import type { ReactNode } from 'react';

interface Props {
  titulo?: string;
  descripcion?: string;
  icono?: ReactNode;
  acciones?: ReactNode;
  children?: ReactNode;
  className?: string;
}

export function Card({ titulo, descripcion, icono, acciones, children, className }: Props) {
  return (
    <section className={`card ${className ?? ''}`.trim()}>
      {(titulo || acciones) && (
        <header className="card__cabecera">
          <div className="card__titulos">
            {icono && <span className="card__icono">{icono}</span>}
            <div>
              {titulo && <h2 className="card__titulo">{titulo}</h2>}
              {descripcion && <p className="card__descripcion">{descripcion}</p>}
            </div>
          </div>
          {acciones && <div className="card__acciones">{acciones}</div>}
        </header>
      )}
      {children}
    </section>
  );
}

export function StatCard({ etiqueta, valor, icono }: { etiqueta: string; valor: ReactNode; icono?: ReactNode }) {
  return (
    <div className="stat">
      {icono && <span className="stat__icono">{icono}</span>}
      <div>
        <p className="stat__etiqueta">{etiqueta}</p>
        <p className="stat__valor">{valor}</p>
      </div>
    </div>
  );
}

export function PageHeader({ titulo, descripcion, acciones }: { titulo: string; descripcion?: string; acciones?: ReactNode }) {
  return (
    <div className="page-header">
      <div>
        <h1>{titulo}</h1>
        {descripcion && <p>{descripcion}</p>}
      </div>
      {acciones && <div className="page-header__acciones">{acciones}</div>}
    </div>
  );
}

export function Badge({ children, tono = 'neutro' }: { children: ReactNode; tono?: 'neutro' | 'exito' | 'alerta' | 'peligro' | 'info' }) {
  return <span className={`badge badge--${tono}`}>{children}</span>;
}
