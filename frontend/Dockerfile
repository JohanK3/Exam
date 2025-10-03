# Stage 1: Build Angular App
FROM node:18-alpine AS build

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install Angular CLI and dependencies
RUN npm install -g @angular/cli
RUN npm install

# Copy all files to container
COPY . .

# Build the Angular app in production mode
RUN ng build --configuration production

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Remove default nginx index page
RUN rm -rf /usr/share/nginx/html/*

# Copier le fichier nginx.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy Angular build files to Nginx web folder
COPY --from=build /app/dist/demo /usr/share/nginx/html/


EXPOSE 8090

CMD ["nginx", "-g", "daemon off;"]

