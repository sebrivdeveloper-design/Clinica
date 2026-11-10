import type { ReactNode } from 'react';
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';
import { AuthProvider } from './auth/AuthContext';
import { ProtectedRoute, RoleRoute } from './auth/ProtectedRoute';
import { ToastProvider } from './components/ui/Toast';
import AppLayout from './layout/AppLayout';
import { rolesDe } from './navigation/menu';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import AgendaPage from './pages/AgendaPage';
import CitasPage from './pages/CitasPage';
import HistoriasPage from './pages/HistoriasPage';
import ConsultaPage from './pages/ConsultaPage';
import RecetasPage from './pages/RecetasPage';
import MedicamentosPage from './pages/MedicamentosPage';
import EntregasPage from './pages/EntregasPage';
import ReportesPage from './pages/ReportesPage';
import NotFoundPage from './pages/NotFoundPage';

/** Rutas protegidas: los roles permitidos salen de navigation/menu.ts. */
const PAGINAS: Record<string, ReactNode> = {
  '/agenda': <AgendaPage />,
  '/citas': <CitasPage />,
  '/historias': <HistoriasPage />,
  '/consultas': <ConsultaPage />,
  '/recetas': <RecetasPage />,
  '/medicamentos': <MedicamentosPage />,
  '/entregas': <EntregasPage />,
  '/reportes': <ReportesPage />,
};

export default function App() {
  return (
    <BrowserRouter>
      <ToastProvider>
        <AuthProvider>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route element={<ProtectedRoute />}>
              <Route element={<AppLayout />}>
                <Route path="/" element={<Navigate to="/inicio" replace />} />
                <Route path="/inicio" element={<DashboardPage />} />
                {Object.entries(PAGINAS).map(([ruta, pagina]) => (
                  <Route key={ruta} path={ruta} element={<RoleRoute roles={rolesDe(ruta)}>{pagina}</RoleRoute>} />
                ))}
                <Route path="*" element={<NotFoundPage />} />
              </Route>
            </Route>
          </Routes>
        </AuthProvider>
      </ToastProvider>
    </BrowserRouter>
  );
}
