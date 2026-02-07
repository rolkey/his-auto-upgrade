#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}   升级模块系统目录创建脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo

# 检查是否以root身份运行
if [[ $EUID -ne 0 ]]; then
   echo -e "${YELLOW}[警告] 推荐以root身份运行此脚本${NC}"
   read -p "继续吗? (y/n): " -n 1 -r
   echo
   if [[ ! $REPLY =~ ^[Yy]$ ]]; then
       exit 1
   fi
fi

# 设置基础目录
BASE_DIR=$(pwd)
BACKEND_DIR="$BASE_DIR/backend"
FRONTEND_DIR="$BASE_DIR/frontend"
SCRIPTS_DIR="$BASE_DIR/scripts"
DEPLOY_DIR="/var/www/deployments"
BACKUP_DIR="/var/www/backups"
TEMP_DIR="/tmp/upgrade"

echo "基础目录: $BASE_DIR"
echo

# 创建主项目目录
mkdir -p "$BASE_DIR"
cd "$BASE_DIR"

# 创建后端目录结构
echo -e "${GREEN}[1/4] 创建后端目录结构...${NC}"
mkdir -p "$BACKEND_DIR/src/upgrade"
mkdir -p "$BACKEND_DIR/src/services"
mkdir -p "$BACKEND_DIR/src/config"
mkdir -p "$BACKEND_DIR/test"
mkdir -p "$BACKEND_DIR/dist"

# 创建后端文件
cat > "$BACKEND_DIR/src/config/upgrade.config.ts" << 'EOF'
// 升级配置文件
export const upgradeConfig = {
  github: {
    baseUrl: 'https://api.github.com',
    owner: 'your-username',
    repos: {
      'micro-frontend-1': 'micro-frontend-1-repo',
      'micro-frontend-2': 'micro-frontend-2-repo',
      'micro-service-1': 'micro-service-1-repo',
      'micro-service-2': 'micro-service-2-repo',
    }
  },
  deployment: {
    basePath: '/var/www/deployments',
    tempPath: '/tmp/upgrade',
    backupPath: '/var/www/backups'
  }
};
EOF

cat > "$BACKEND_DIR/src/upgrade/upgrade.service.ts" << 'EOF'
// 升级服务文件占位
import { Injectable } from '@nestjs/common';

@Injectable()
export class UpgradeService {
  constructor() {}
}
EOF

# 创建前端目录结构
echo -e "${GREEN}[2/4] 创建前端目录结构...${NC}"
mkdir -p "$FRONTEND_DIR/src/components"
mkdir -p "$FRONTEND_DIR/src/views"
mkdir -p "$FRONTEND_DIR/src/router"
mkdir -p "$FRONTEND_DIR/src/store"
mkdir -p "$FRONTEND_DIR/public"
mkdir -p "$FRONTEND_DIR/dist"

# 创建前端文件
cat > "$FRONTEND_DIR/src/components/UpgradePanel.vue" << 'EOF'
<!-- 升级面板组件占位 -->
<template>
  <div>升级面板</div>
</template>

<script setup>
// Vue 3 组件
</script>
EOF

# 创建脚本目录
echo -e "${GREEN}[3/4] 创建脚本目录结构...${NC}"
mkdir -p "$SCRIPTS_DIR/backups"
mkdir -p "$SCRIPTS_DIR/logs"

# 创建脚本文件
cat > "$SCRIPTS_DIR/upgrade-manager.js" << 'EOF'
#!/usr/bin/env node
// 升级管理器脚本
console.log('升级管理器');
EOF

chmod +x "$SCRIPTS_DIR/upgrade-manager.js"
echo "{}" > "$SCRIPTS_DIR/config.json"

# 创建部署目录（需要root权限）
echo -e "${GREEN}[4/4] 创建系统部署目录...${NC}"
mkdir -p "$DEPLOY_DIR"
mkdir -p "$BACKUP_DIR"
mkdir -p "$TEMP_DIR"

# 设置部署目录权限
chmod 755 "$DEPLOY_DIR"
chmod 755 "$BACKUP_DIR"
chmod 777 "$TEMP_DIR"

echo "创建部署目录: $DEPLOY_DIR"
echo "创建备份目录: $BACKUP_DIR"
echo "创建临时目录: $TEMP_DIR"

# 创建微服务目录
echo
echo -e "${GREEN}正在创建微服务示例目录...${NC}"
MICRO_SERVICES="$DEPLOY_DIR/micro-services"
mkdir -p "$MICRO_SERVICES"

services=("auth-service" "user-service" "order-service" "product-service")
for service in "${services[@]}"; do
    SERVICE_DIR="$MICRO_SERVICES/$service"
    mkdir -p "$SERVICE_DIR"
    mkdir -p "$SERVICE_DIR/dist"
    
    cat > "$SERVICE_DIR/package.json" << EOF
{
  "name": "$service",
  "version": "1.0.0",
  "description": "$service microservice",
  "main": "dist/index.js",
  "scripts": {
    "start": "node dist/index.js",
    "build": "tsc",
    "dev": "nodemon src/index.ts"
  }
}
EOF
    
    mkdir -p "$SERVICE_DIR/src"
    cat > "$SERVICE_DIR/src/index.ts" << EOF
// $service 主文件
console.log('$service started');
EOF
    
    echo "创建微服务: $service"
done

# 创建微前端目录
echo
echo -e "${GREEN}正在创建微前端示例目录...${NC}"
MICRO_FRONTENDS="$DEPLOY_DIR/micro-frontends"
mkdir -p "$MICRO_FRONTENDS"

frontends=("admin-app" "user-app" "dashboard-app" "settings-app")
for frontend in "${frontends[@]}"; do
    FRONTEND_APP_DIR="$MICRO_FRONTENDS/$frontend"
    mkdir -p "$FRONTEND_APP_DIR"
    mkdir -p "$FRONTEND_APP_DIR/dist"
    
    cat > "$FRONTEND_APP_DIR/package.json" << EOF
{
  "name": "$frontend",
  "version": "1.0.0",
  "description": "$frontend micro frontend",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.0.0",
    "vite": "^4.0.0"
  }
}
EOF
    
    mkdir -p "$FRONTEND_APP_DIR/src"
    cat > "$FRONTEND_APP_DIR/src/App.vue" << EOF
<!-- $frontend 主页面 -->
<template>
  <div>$frontend</div>
</template>

<script setup>
// Vue 3 组件
</script>
EOF
    
    echo "创建微前端: $frontend"
done

# 创建环境配置文件
echo
echo -e "${GREEN}正在创建配置文件...${NC}"

cat > "$BASE_DIR/.env" << EOF
NODE_ENV=development
PORT=3000
GITHUB_TOKEN=your_personal_access_token_here
DEPLOYMENT_PATH=$DEPLOY_DIR
BACKUP_PATH=$BACKUP_DIR
TEMP_PATH=$TEMP_DIR

DATABASE_URL=postgresql://localhost:5432/upgrade_db
REDIS_URL=redis://localhost:6379

# 微服务配置
AUTH_SERVICE_URL=http://localhost:3001
USER_SERVICE_URL=http://localhost:3002
ORDER_SERVICE_URL=http://localhost:3003
PRODUCT_SERVICE_URL=http://localhost:3004

# 微前端配置
ADMIN_APP_URL=http://localhost:8081
USER_APP_URL=http://localhost:8082
DASHBOARD_APP_URL=http://localhost:8083
SETTINGS_APP_URL=http://localhost:8084
EOF

# 创建Docker配置文件
echo
echo -e "${GREEN}正在创建Docker配置...${NC}"

cat > "$BASE_DIR/docker-compose.yml" << 'EOF'
version: '3.8'

services:
  # 数据库
  postgres:
    image: postgres:14-alpine
    environment:
      POSTGRES_DB: upgrade_db
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis缓存
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # 后端服务
  backend:
    build: ./backend
    ports:
      - "3000:3000"
    volumes:
      - $DEPLOY_DIR:/app/deployments
      - $BACKUP_DIR:/app/backups
      - $TEMP_DIR:/tmp/upgrade
    environment:
      - NODE_ENV=production
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - DEPLOYMENT_PATH=/app/deployments
      - BACKUP_PATH=/app/backups
      - TEMP_PATH=/tmp/upgrade
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    restart: unless-stopped

  # 前端服务
  frontend:
    build: ./frontend
    ports:
      - "8080:80"
    depends_on:
      - backend
    restart: unless-stopped

  # Nginx反向代理（可选）
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./nginx/ssl:/etc/nginx/ssl
      - $DEPLOY_DIR/micro-frontends:/var/www/micro-frontends
    depends_on:
      - backend
      - frontend
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
EOF

# 创建NGINX配置目录
mkdir -p "$BASE_DIR/nginx"
mkdir -p "$BASE_DIR/nginx/ssl"

cat > "$BASE_DIR/nginx/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 升级管理后端
    upstream upgrade_backend {
        server backend:3000;
    }

    # 升级管理前端
    upstream upgrade_frontend {
        server frontend:80;
    }

    server {
        listen 80;
        server_name localhost;

        # 升级管理前端
        location / {
            proxy_pass http://upgrade_frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # 升级管理API
        location /api/ {
            proxy_pass http://upgrade_backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }

        # 微前端静态文件服务
        location ~ ^/micro-frontends/(.*)$ {
            root /var/www;
            try_files $uri $uri/ /$1/index.html;
        }
    }
}
EOF

# 创建package.json文件
echo
echo -e "${GREEN}正在创建package.json文件...${NC}"

cat > "$BACKEND_DIR/package.json" << 'EOF'
{
  "name": "upgrade-backend",
  "version": "1.0.0",
  "description": "NestJS升级管理后端",
  "main": "dist/main.js",
  "scripts": {
    "build": "nest build",
    "start": "node dist/main.js",
    "start:dev": "nest start --watch",
    "start:debug": "nest start --debug --watch",
    "start:prod": "node dist/main.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:cov": "jest --coverage",
    "lint": "eslint \"src/**/*.ts\" --fix",
    "format": "prettier --write \"src/**/*.ts\""
  },
  "dependencies": {
    "@nestjs/common": "^9.0.0",
    "@nestjs/core": "^9.0.0",
    "@nestjs/platform-express": "^9.0.0",
    "@octokit/rest": "^19.0.0",
    "fs-extra": "^11.0.0",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.0.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^9.0.0",
    "@nestjs/testing": "^9.0.0",
    "@types/fs-extra": "^11.0.0",
    "@types/node": "^18.0.0",
    "typescript": "^4.7.0",
    "jest": "^28.0.0",
    "@types/jest": "^28.0.0",
    "ts-jest": "^28.0.0",
    "@typescript-eslint/eslint-plugin": "^5.0.0",
    "@typescript-eslint/parser": "^5.0.0",
    "eslint": "^8.0.0",
    "prettier": "^2.7.0"
  }
}
EOF

cat > "$FRONTEND_DIR/package.json" << 'EOF'
{
  "name": "upgrade-frontend",
  "version": "1.0.0",
  "description": "Vue3升级管理前端",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "vue": "^3.2.0",
    "element-plus": "^2.2.0",
    "axios": "^1.0.0",
    "vue-router": "^4.0.0",
    "pinia": "^2.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^4.0.0",
    "vite": "^4.0.0",
    "@vue/compiler-sfc": "^3.2.0",
    "sass": "^1.55.0"
  }
}
EOF

# 创建说明文件
echo
echo -e "${GREEN}正在创建文档...${NC}"

cat > "$BASE_DIR/README.md" << 'EOF'
# 升级模块系统

## 项目结构
