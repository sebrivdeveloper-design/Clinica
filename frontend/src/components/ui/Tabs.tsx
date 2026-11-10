import type { ReactNode } from 'react';

export interface Pestana {
  id: string;
  etiqueta: string;
  icono?: ReactNode;
}

export function Tabs({ pestanas, activa, alCambiar }: { pestanas: Pestana[]; activa: string; alCambiar: (id: string) => void }) {
  return (
    <div className="tabs" role="tablist">
      {pestanas.map((p) => (
        <button
          key={p.id}
          role="tab"
          aria-selected={p.id === activa}
          className={`tabs__item${p.id === activa ? ' tabs__item--activa' : ''}`}
          onClick={() => alCambiar(p.id)}
        >
          {p.icono}
          <span>{p.etiqueta}</span>
        </button>
      ))}
    </div>
  );
}
