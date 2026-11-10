import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { HeartPulse, LogOut, Menu, X } from 'lucide-react';
import { useAuth, useSesion } from '../auth/AuthContext';
import { menuPara } from '../navigation/menu';
import { ETIQUETA_ROL } from '../types/auth';
import { ConfirmDialog } from '../components/ui/ConfirmDialog';

function iniciales(nombre: string): string {
  return nombre.replace(/[^a-zA-Z]/g, '').slice(0, 2).toUpperCase() || 'U';
}

/** Estructura principal: barra lateral por rol + barra superior + contenido. */
export default function AppLayout() {
  const sesion = useSesion();
  const { cerrarSesion } = useAuth();
  const [menuAbierto, setMenuAbierto] = useState(false);
  const [confirmarSalida, setConfirmarSalida] = useState(false);
  const location = useLocation();
  const items = menuPara(sesion.rol);

  // Cierra el menú móvil al navegar.
  useEffect(() => setMenuAbierto(false), [location.pathname]);

  return (
    <div className={`app${menuAbierto ? ' app--menu-abierto' : ''}`}>
      <aside className="sidebar" aria-label="Navegación principal">
        <div className="sidebar__marca">
          <span className="logo">
            <HeartPulse size={22} aria-hidden />
          </span>
          <div>
            <strong>Clínica</strong>
            <small>Citas médicas</small>
          </div>
          <button className="sidebar__cerrar" onClick={() => setMenuAbierto(false)} aria-label="Cerrar menú">
            <X size={20} />
          </button>
        </div>
        <nav className="sidebar__nav">
          <p className="sidebar__seccion">{ETIQUETA_ROL[sesion.rol]}</p>
          {items.map(({ ruta, etiqueta, icono: Icono }) => (
            <NavLink key={ruta} to={ruta} className={({ isActive }) => `nav-item${isActive ? ' nav-item--activo' : ''}`}>
              <Icono size={18} aria-hidden />
              <span>{etiqueta}</span>
            </NavLink>
          ))}
        </nav>
        <div className="sidebar__pie">
          <button className="nav-item nav-item--salir" onClick={() => setConfirmarSalida(true)}>
            <LogOut size={18} aria-hidden />
            <span>Cerrar sesión</span>
          </button>
        </div>
      </aside>
      <div className="sidebar-fondo" onClick={() => setMenuAbierto(false)} aria-hidden />

      <div className="principal">
        <header className="topbar">
          <button className="topbar__menu" onClick={() => setMenuAbierto(true)} aria-label="Abrir menú">
            <Menu size={22} />
          </button>
          <div className="topbar__espacio" />
          <div className="usuario">
            <div className="usuario__texto">
              <strong>{sesion.username}</strong>
              <small>
                {ETIQUETA_ROL[sesion.rol]}
                {sesion.idEntidad != null && ` · ID ${sesion.idEntidad}`}
              </small>
            </div>
            <span className="avatar" aria-hidden>
              {iniciales(sesion.username)}
            </span>
          </div>
        </header>
        <main className="contenido">
          <Outlet />
        </main>
      </div>

      <ConfirmDialog
        abierto={confirmarSalida}
        titulo="¿Cerrar sesión?"
        textoConfirmar="Cerrar sesión"
        alConfirmar={() => cerrarSesion()}
        alCancelar={() => setConfirmarSalida(false)}
      >
        <p>Deberá ingresar nuevamente sus credenciales para continuar.</p>
      </ConfirmDialog>
    </div>
  );
}
