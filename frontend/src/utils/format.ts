/** Utilidades de presentación (solo formato visual, sin reglas de negocio). */

const FECHA_HORA = new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium', timeStyle: 'short' });
const FECHA = new Intl.DateTimeFormat('es-CO', { dateStyle: 'medium' });

export function formatearFecha(valor: unknown): string {
  if (valor == null || valor === '') return '—';
  const texto = String(valor);
  const soloFecha = /^\d{4}-\d{2}-\d{2}$/.test(texto);
  const d = new Date(soloFecha ? `${texto}T00:00:00` : texto);
  if (Number.isNaN(d.getTime())) return texto;
  return soloFecha ? FECHA.format(d) : FECHA_HORA.format(d);
}

/** fechaHoraInicio -> "Fecha hora inicio" */
export function etiquetaCampo(clave: string): string {
  const s = clave.replace(/([a-z0-9])([A-Z])/g, '$1 $2').replace(/_/g, ' ').toLowerCase();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export function formatearValor(valor: unknown): string {
  if (valor == null || valor === '') return '—';
  if (typeof valor === 'string' && /^\d{4}-\d{2}-\d{2}(T|$)/.test(valor)) return formatearFecha(valor);
  if (typeof valor === 'number') return valor.toLocaleString('es-CO');
  if (typeof valor === 'object') return JSON.stringify(valor);
  return String(valor);
}

/** Fecha local en formato yyyy-MM-dd (para inputs type=date y la API). */
export function fechaISO(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Intenta leer un identificador devuelto por el procedimiento (ej. idCita). */
export function leerId(datos: unknown, ...claves: string[]): number | null {
  if (!datos || typeof datos !== 'object') return null;
  const obj = datos as Record<string, unknown>;
  for (const c of claves) {
    const v = obj[c];
    if (typeof v === 'number') return v;
    if (typeof v === 'string' && /^\d+$/.test(v)) return Number(v);
  }
  return null;
}
