# Étape de build
FROM node:16 AS build
LABEL authors="karl"
WORKDIR /app
COPY package*.json ./
RUN npm install -g @angular/cli@14 && npm install --legacy-peer-deps
COPY . .
RUN npm run build

# Étape de production
FROM nginx:alpine
COPY --from=build /app/dist/demo /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]