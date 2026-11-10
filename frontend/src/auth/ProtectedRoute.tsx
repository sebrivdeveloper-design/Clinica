import type { ReactNode } from 'react';
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import type { Rol } from '../types/auth';
import { useAuth } from './AuthContext';
import ForbiddenPage from '../pages/ForbiddenPage';

/** Exige sesión activa; si no la hay, redirige al login recordando la ruta pedida. */
export function ProtectedRoute() {
  const { sesion } = useAuth();
  const location = useLocation();
  if (!sesion) return <Navigate to="/login" replace state={{ from: location.pathname }} />;
  return <Outlet />;
}

/**
 * Control VISUAL de navegación por rol. No es una medida de seguridad:
 * Oracle valida los permisos de cada operación (código 20005).
 */
export function RoleRoute({ roles, children }: { roles: readonly Rol[]; children: ReactNode }) {
  const { sesion } = useAuth();
  if (!sesion || !roles.includes(sesion.rol)) return <ForbiddenPage />;
  return <>{children}</>;
}
