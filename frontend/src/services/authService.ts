import { http } from '../api/httpClient';
import type { LoginRequest, LoginResponse } from '../types/auth';

/** POST /api/auth/login — Oracle valida credenciales con PKG_SEGURIDAD.LOGIN. [Disponible] */
export const authService = {
  login: (datos: LoginRequest) => http.post<LoginResponse>('/api/auth/login', datos, { auth: false }),
};
