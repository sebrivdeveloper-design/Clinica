import type { ComponentPropsWithRef, ReactNode } from 'react';
import { Spinner } from './Feedback';

interface Props extends ComponentPropsWithRef<'button'> {
  variante?: 'primario' | 'secundario' | 'peligro' | 'fantasma';
  cargando?: boolean;
  icono?: ReactNode;
  bloque?: boolean;
}

export function Button({ variante = 'primario', cargando, icono, bloque, children, disabled, className, ...rest }: Props) {
  const clases = ['btn', `btn--${variante}`, bloque ? 'btn--bloque' : '', className ?? ''].join(' ').trim();
  return (
    <button className={clases} disabled={disabled || cargando} aria-busy={cargando} {...rest}>
      {cargando ? <Spinner pequeno /> : icono}
      {children && <span>{children}</span>}
    </button>
  );
}
