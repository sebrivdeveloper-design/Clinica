import { Link } from 'react-router-dom';
import { ShieldOff } from 'lucide-react';

export default function ForbiddenPage() {
  return (
    <div className="estado estado--pagina">
      <div className="estado__icono">
        <ShieldOff size={28} aria-hidden />
      </div>
      <h3>Módulo no disponible para su rol</h3>
      <p className="estado__texto">Esta sección no forma parte del menú asignado a su perfil.</p>
      <Link className="btn btn--primario" to="/inicio">
        <span>Ir al panel principal</span>
      </Link>
    </div>
  );
}
