import { useEffect, useRef, type ReactNode } from 'react';
import { AlertTriangle } from 'lucide-react';
import { Button } from './Button';

interface Props {
  abierto: boolean;
  titulo: string;
  children?: ReactNode;
  textoConfirmar?: string;
  peligro?: boolean;
  cargando?: boolean;
  alConfirmar: () => void;
  alCancelar: () => void;
}

/** Modal de confirmación accesible (Esc para cerrar, foco inicial en Cancelar). */
export function ConfirmDialog({
  abierto,
  titulo,
  children,
  textoConfirmar = 'Confirmar',
  peligro,
  cargando,
  alConfirmar,
  alCancelar,
}: Props) {
  const cancelarRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (!abierto) return;
    cancelarRef.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape' && !cargando) alCancelar();
    };
    document.addEventListener('keydown', onKey);
    return () => document.removeEventListener('keydown', onKey);
  }, [abierto, cargando, alCancelar]);

  if (!abierto) return null;
  return (
    <div className="modal-fondo" onMouseDown={() => !cargando && alCancelar()}>
      <div
        className="modal"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="modal-titulo"
        onMouseDown={(e) => e.stopPropagation()}
      >
        <div className={`modal__icono${peligro ? ' modal__icono--peligro' : ''}`}>
          <AlertTriangle size={22} aria-hidden />
        </div>
        <h2 id="modal-titulo">{titulo}</h2>
        <div className="modal__cuerpo">{children}</div>
        <div className="modal__acciones">
          <Button ref={cancelarRef} variante="secundario" onClick={alCancelar} disabled={cargando}>
            Cancelar
          </Button>
          <Button variante={peligro ? 'peligro' : 'primario'} onClick={alConfirmar} cargando={cargando}>
            {textoConfirmar}
          </Button>
        </div>
      </div>
    </div>
  );
}
