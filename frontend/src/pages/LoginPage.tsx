import { useState, type FormEvent } from 'react';
import { Navigate, useLocation, useNavigate } from 'react-router-dom';
import { CalendarCheck, Eye, EyeOff, HeartPulse, Lock, ShieldCheck, Stethoscope, User } from 'lucide-react';
import { useAuth } from '../auth/AuthContext';
import { aApiError } from '../api/apiError';
import { describirError } from '../api/errorMessages';
import { Button } from '../components/ui/Button';

export default function LoginPage() {
  const { sesion, iniciarSesion, avisoCierre } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const destino = (location.state as { from?: string } | null)?.from ?? '/inicio';

  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [verClave, setVerClave] = useState(false);
  const [enviando, setEnviando] = useState(false);
  const [error, setError] = useState<{ titulo: string; detalle?: string } | null>(null);

  if (sesion) return <Navigate to={destino} replace />;

  async function enviar(e: FormEvent) {
    e.preventDefault();
    setEnviando(true);
    setError(null);
    try {
      await iniciarSesion(username.trim(), password);
      navigate(destino, { replace: true });
    } catch (err) {
      setError(describirError(aApiError(err)));
      setPassword('');
    } finally {
      setEnviando(false);
    }
  }

  return (
    <div className="login">
      <section className="login__panel" aria-hidden>
        <div className="login__marca">
          <span className="logo logo--grande">
            <HeartPulse size={28} />
          </span>
          <strong>Clínica</strong>
        </div>
        <h1>Gestión de citas médicas</h1>
        <p>Agenda, historias clínicas, recetas y farmacia en un solo lugar.</p>
        <ul className="login__puntos">
          <li>
            <CalendarCheck size={18} /> Reserva y control de citas
          </li>
          <li>
            <Stethoscope size={18} /> Historias clínicas y recetas
          </li>
          <li>
            <ShieldCheck size={18} /> Permisos validados por la base de datos
          </li>
        </ul>
      </section>

      <section className="login__form-wrap">
        <form className="login__form" onSubmit={enviar} noValidate>
          <div className="login__marca login__marca--movil">
            <span className="logo">
              <HeartPulse size={22} />
            </span>
            <strong>Clínica</strong>
          </div>
          <h2>Iniciar sesión</h2>
          <p className="login__sub">Ingrese con su usuario asignado.</p>

          {avisoCierre && !error && (
            <div className="aviso aviso--info" role="status">
              <p>{avisoCierre}</p>
            </div>
          )}
          {error && (
            <div className="aviso aviso--error" role="alert">
              <div>
                <strong>{error.titulo}</strong>
                {error.detalle && <p>{error.detalle}</p>}
              </div>
            </div>
          )}

          <div className="campo">
            <label htmlFor="usuario" className="campo__etiqueta">
              Usuario
            </label>
            <div className="input-icono">
              <User size={18} aria-hidden />
              <input
                id="usuario"
                className="input"
                autoComplete="username"
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                required
                autoFocus
              />
            </div>
          </div>

          <div className="campo">
            <label htmlFor="clave" className="campo__etiqueta">
              Contraseña
            </label>
            <div className="input-icono">
              <Lock size={18} aria-hidden />
              <input
                id="clave"
                className="input"
                type={verClave ? 'text' : 'password'}
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                className="input-icono__accion"
                onClick={() => setVerClave((v) => !v)}
                aria-label={verClave ? 'Ocultar contraseña' : 'Mostrar contraseña'}
              >
                {verClave ? <EyeOff size={18} /> : <Eye size={18} />}
              </button>
            </div>
          </div>

          <Button type="submit" bloque cargando={enviando} disabled={!username.trim() || !password}>
            Ingresar
          </Button>
        </form>
      </section>
    </div>
  );
}
