/** Configuración de la API, leída de variables de entorno (.env). */
export const env = {
  apiBaseUrl: (import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8080').replace(/\/+$/, ''),
};
