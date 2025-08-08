// src/environments/environment.prod.ts
export const environment = {
  production: true,
  // Modifiez l'URL de l'API pour qu'elle pointe vers le proxy Nginx
  // Le chemin "/api/" correspond à la configuration Nginx
  API_URL: '/api',
};