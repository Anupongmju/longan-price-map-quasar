# Stage 1: Build Quasar SPA
FROM node:20-alpine AS builder

WORKDIR /app

# Copy everything first (แก้ปัญหา quasar prepare หาไฟล์ไม่เจอ)
COPY . .

# Install dependencies
RUN npm ci --legacy-peer-deps

# Build Quasar SPA
RUN npm run build


# Stage 2: Nginx serve static files
FROM nginx:1.27-alpine

# ลบ html เดิม
RUN rm -rf /usr/share/nginx/html/*

# Copy build result เข้า nginx
COPY --from=builder /app/dist/spa /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
