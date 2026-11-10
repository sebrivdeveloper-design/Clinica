/**
 * Lee (sin verificar) los claims del JWT para conocer expiración y usuario.
 * La verificación real de la firma la hace el backend en cada petición.
 */
export interface ClaimsJwt {
  sub?: string;
  username?: string;
  rol?: string;
  idEntidad?: number;
  exp?: number;
}

export function leerClaims(token: string): ClaimsJwt {
  try {
    const payload = token.split('.')[1] ?? '';
    const base64 = payload.replace(/-/g, '+').replace(/_/g, '/');
    const json = decodeURIComponent(
      atob(base64)
        .split('')
        .map((c) => '%' + c.charCodeAt(0).toString(16).padStart(2, '0'))
        .join(''),
    );
    return JSON.parse(json) as ClaimsJwt;
  } catch {
    return {};
  }
}
