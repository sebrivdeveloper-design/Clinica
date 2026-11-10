import type { ReactNode } from 'react';
import { etiquetaCampo, formatearValor } from '../../utils/format';

export interface Columna<T> {
  clave: string;
  titulo?: string;
  render?: (fila: T) => ReactNode;
  alinear?: 'izq' | 'der';
}

interface Props<T> {
  filas: T[];
  /** Si se omite, las columnas se generan a partir de la primera fila. */
  columnas?: Columna<T>[];
  claveFila?: (fila: T, i: number) => string | number;
  acciones?: (fila: T) => ReactNode;
  titulo?: string;
}

/**
 * Tabla legible y responsive. En pantallas pequeñas cada fila se muestra como
 * tarjeta usando el atributo data-etiqueta de cada celda.
 */
export function DataTable<T extends Record<string, unknown>>({ filas, columnas, claveFila, acciones, titulo }: Props<T>) {
  const cols: Columna<T>[] = columnas ?? Object.keys(filas[0] ?? {}).map((clave) => ({ clave }));
  return (
    <div className="tabla-wrap">
      <table className="tabla">
        {titulo && <caption className="sr-only">{titulo}</caption>}
        <thead>
          <tr>
            {cols.map((c) => (
              <th key={c.clave} className={c.alinear === 'der' ? 'der' : undefined}>
                {c.titulo ?? etiquetaCampo(c.clave)}
              </th>
            ))}
            {acciones && <th className="der">Acciones</th>}
          </tr>
        </thead>
        <tbody>
          {filas.map((f, i) => (
            <tr key={claveFila ? claveFila(f, i) : i}>
              {cols.map((c) => (
                <td key={c.clave} data-etiqueta={c.titulo ?? etiquetaCampo(c.clave)} className={c.alinear === 'der' ? 'der' : undefined}>
                  {c.render ? c.render(f) : formatearValor(f[c.clave])}
                </td>
              ))}
              {acciones && (
                <td className="der tabla__acciones" data-etiqueta="Acciones">
                  {acciones(f)}
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
