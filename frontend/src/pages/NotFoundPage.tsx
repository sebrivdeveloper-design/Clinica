import { Link } from 'react-router-dom';
import { Compass } from 'lucide-react';

export default function NotFoundPage() {
  return (
    <div className="estado estado--pagina">
      <div className="estado__icono">
        <Compass size={28} aria-hidden />
      </div>
      <h3>Página no encontrada</h3>
      <p className="estado__texto">La dirección solicitada no existe.</p>
      <Link className="btn btn--primario" to="/inicio">
        <span>Ir al panel principal</span>
      </Link>
    </div>
  );
}
