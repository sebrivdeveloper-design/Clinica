import { useId, type InputHTMLAttributes, type ReactNode, type TextareaHTMLAttributes } from 'react';

interface CampoProps {
  etiqueta: string;
  ayuda?: string;
  requerido?: boolean;
  children: (id: string) => ReactNode;
}

/** Etiqueta + control + texto de ayuda, con accesibilidad resuelta. */
export function Campo({ etiqueta, ayuda, requerido, children }: CampoProps) {
  const id = useId();
  return (
    <div className="campo">
      <label htmlFor={id} className="campo__etiqueta">
        {etiqueta}
        {requerido && <span className="campo__req" aria-hidden> *</span>}
      </label>
      {children(id)}
      {ayuda && <p className="campo__ayuda">{ayuda}</p>}
    </div>
  );
}

type InputProps = InputHTMLAttributes<HTMLInputElement> & { etiqueta: string; ayuda?: string };

export function CampoTexto({ etiqueta, ayuda, required, ...rest }: InputProps) {
  return (
    <Campo etiqueta={etiqueta} ayuda={ayuda} requerido={required}>
      {(id) => <input id={id} className="input" required={required} {...rest} />}
    </Campo>
  );
}

type AreaProps = TextareaHTMLAttributes<HTMLTextAreaElement> & { etiqueta: string; ayuda?: string };

export function CampoArea({ etiqueta, ayuda, required, ...rest }: AreaProps) {
  return (
    <Campo etiqueta={etiqueta} ayuda={ayuda} requerido={required}>
      {(id) => <textarea id={id} className="input input--area" required={required} {...rest} />}
    </Campo>
  );
}

export function FilaFormulario({ children }: { children: ReactNode }) {
  return <div className="form-fila">{children}</div>;
}

/** Convierte el valor de un input numérico; devuelve null si está vacío o no es entero positivo. */
// eslint-disable-next-line react-refresh/only-export-components
export function enteroPositivo(valor: string): number | null {
  const n = Number(valor);
  return valor.trim() !== '' && Number.isInteger(n) && n > 0 ? n : null;
}
