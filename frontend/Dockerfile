# Étape 1 : Build avec Node
FROM node:16 AS build
WORKDIR /app

# Augmenter le timeout de npm
RUN npm config set fetch-retry-maxtimeout 300000

COPY package*.json ./
RUN npm install -g @angular/cli@14 && npm install --legacy-peer-deps
COPY . .
RUN npm run build --prod || { echo "Build failed"; exit 1; }
# Vérifier si le dossier dist/demo existe
RUN ls -l /app/dist || { echo "dist directory not found"; exit 1; }
RUN ls -l /app/dist/demo || { echo "dist/demo directory not found"; exit 1; }

# Étape 2 : Servir avec Nginx
FROM nginx:alpine
COPY --from=build /app/dist/demo /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf