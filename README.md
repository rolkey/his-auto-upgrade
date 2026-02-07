理解了！我们只需要一个极简的升级模块，直接从GitHub获取代码、构建、然后部署到指定目录。让我提供一个更简洁的实现：

## 1. 核心升级服务 - 简化版

### `src/upgrade/upgrade.service.ts`

```typescript
import { Injectable, Logger } from "@nestjs/common";
import { exec } from "child_process";
import { promisify } from "util";
import * as fs from "fs-extra";
import * as path from "path";

const execAsync = promisify(exec);

interface ModuleConfig {
  name: string;
  repo: string; // GitHub仓库地址，格式：owner/repo
  type: "frontend" | "backend" | "microfrontend";
  deployPath: string; // 部署目标路径
  buildCommand: string; // 构建命令，默认 'npm run build'
  branch?: string; // 分支，默认 'main'
}

interface UpgradeResult {
  success: boolean;
  module: string;
  message: string;
  timestamp: string;
  version?: string;
}

@Injectable()
export class UpgradeService {
  private readonly logger = new Logger(UpgradeService.name);

  // 模块配置
  private readonly modules: ModuleConfig[] = [
    {
      name: "microfrontend-admin",
      repo: "your-org/admin-app",
      type: "microfrontend",
      deployPath: "/var/www/microfrontends/admin",
      buildCommand: "npm run build",
    },
    {
      name: "microfrontend-user",
      repo: "your-org/user-app",
      type: "microfrontend",
      deployPath: "/var/www/microfrontends/user",
      buildCommand: "npm run build",
    },
    {
      name: "auth-service",
      repo: "your-org/auth-service",
      type: "backend",
      deployPath: "/var/www/services/auth",
      buildCommand: "npm run build",
    },
    {
      name: "order-service",
      repo: "your-org/order-service",
      type: "backend",
      deployPath: "/var/www/services/order",
      buildCommand: "npm run build",
    },
  ];

  /**
   * 升级单个模块
   */
  async upgradeModule(moduleName: string): Promise<UpgradeResult> {
    const module = this.modules.find((m) => m.name === moduleName);
    if (!module) {
      return {
        success: false,
        module: moduleName,
        message: `模块 ${moduleName} 未配置`,
        timestamp: new Date().toISOString(),
      };
    }

    const tempDir = path.join("/tmp/upgrade", moduleName);
    const startTime = Date.now();

    try {
      this.logger.log(`开始升级模块: ${moduleName}`);

      // 1. 创建临时目录
      await fs.ensureDir(tempDir);

      // 2. 克隆或拉取代码
      await this.gitCloneOrPull(module, tempDir);

      // 3. 安装依赖
      await this.npmInstall(tempDir);

      // 4. 构建项目
      await this.buildProject(tempDir, module.buildCommand);

      // 5. 备份当前部署（可选）
      await this.backupCurrent(module.deployPath, moduleName);

      // 6. 部署新版本
      await this.deployBuild(tempDir, module.deployPath, module.type);

      // 7. 获取版本信息
      const version = await this.getVersion(tempDir);

      const duration = Date.now() - startTime;
      this.logger.log(`模块 ${moduleName} 升级成功，耗时: ${duration}ms`);

      return {
        success: true,
        module: moduleName,
        message: `升级成功，版本: ${version}`,
        timestamp: new Date().toISOString(),
        version,
      };
    } catch (error) {
      this.logger.error(`模块 ${moduleName} 升级失败:`, error);

      return {
        success: false,
        module: moduleName,
        message: `升级失败: ${error.message}`,
        timestamp: new Date().toISOString(),
      };
    } finally {
      // 清理临时目录
      await this.cleanupTemp(tempDir);
    }
  }

  /**
   * 批量升级模块
   */
  async batchUpgrade(moduleNames?: string[]): Promise<UpgradeResult[]> {
    const modulesToUpgrade = moduleNames
      ? this.modules.filter((m) => moduleNames.includes(m.name))
      : this.modules;

    const results: UpgradeResult[] = [];

    for (const module of modulesToUpgrade) {
      const result = await this.upgradeModule(module.name);
      results.push(result);
    }

    return results;
  }

  /**
   * 获取所有模块状态
   */
  async getModulesStatus() {
    const statusList = [];

    for (const module of this.modules) {
      try {
        const currentVersion = await this.getCurrentVersion(module.deployPath);
        const latestVersion = await this.getGitLatestVersion(module.repo);

        statusList.push({
          name: module.name,
          type: module.type,
          currentVersion,
          latestVersion,
          deployPath: module.deployPath,
          status: currentVersion === latestVersion ? "up-to-date" : "outdated",
          lastUpdated: await this.getLastModifiedTime(module.deployPath),
        });
      } catch (error) {
        statusList.push({
          name: module.name,
          type: module.type,
          currentVersion: "unknown",
          latestVersion: "unknown",
          deployPath: module.deployPath,
          status: "error",
          error: error.message,
        });
      }
    }

    return statusList;
  }

  /**
   * 从GitHub克隆或拉取代码
   */
  private async gitCloneOrPull(module: ModuleConfig, targetDir: string): Promise<void> {
    const repoUrl = `https://github.com/${module.repo}.git`;
    const branch = module.branch || "main";

    const gitDir = path.join(targetDir, ".git");

    if (await fs.pathExists(gitDir)) {
      // 如果已有git仓库，拉取最新
      await execAsync(
        `cd ${targetDir} && git fetch origin && git checkout ${branch} && git pull origin ${branch}`,
      );
    } else {
      // 克隆新仓库
      await execAsync(`git clone --branch ${branch} ${repoUrl} ${targetDir}`);
    }
  }

  /**
   * 安装npm依赖
   */
  private async npmInstall(dir: string): Promise<void> {
    const packageJson = path.join(dir, "package.json");

    if (await fs.pathExists(packageJson)) {
      await execAsync(`cd ${dir} && npm ci --no-audit --no-fund`);
    }
  }

  /**
   * 构建项目
   */
  private async buildProject(dir: string, buildCommand: string): Promise<void> {
    await execAsync(`cd ${dir} && ${buildCommand}`, { maxBuffer: 1024 * 1024 * 10 });
  }

  /**
   * 备份当前部署
   */
  private async backupCurrent(deployPath: string, moduleName: string): Promise<void> {
    if (await fs.pathExists(deployPath)) {
      const backupDir = path.join(
        "/var/www/backups",
        moduleName,
        new Date().toISOString().replace(/:/g, "-"),
      );
      await fs.copy(deployPath, backupDir);
    }
  }

  /**
   * 部署构建产物
   */
  private async deployBuild(
    sourceDir: string,
    targetDir: string,
    type: "frontend" | "backend" | "microfrontend",
  ): Promise<void> {
    // 查找构建输出目录
    let buildOutput = "";

    if (type === "frontend" || type === "microfrontend") {
      // 前端项目通常输出到 dist 或 build 目录
      const possibleDirs = ["dist", "build", "out", "public"];
      for (const dir of possibleDirs) {
        const testPath = path.join(sourceDir, dir);
        if (await fs.pathExists(testPath)) {
          buildOutput = testPath;
          break;
        }
      }
    } else {
      // 后端项目可能输出到 dist 目录，也可能是整个项目
      const distPath = path.join(sourceDir, "dist");
      buildOutput = (await fs.pathExists(distPath)) ? distPath : sourceDir;
    }

    if (!buildOutput) {
      throw new Error("未找到构建输出目录");
    }

    // 清空目标目录（如果存在）
    if (await fs.pathExists(targetDir)) {
      await fs.emptyDir(targetDir);
    } else {
      await fs.ensureDir(targetDir);
    }

    // 复制构建产物
    await fs.copy(buildOutput, targetDir);
  }

  /**
   * 获取版本号
   */
  private async getVersion(dir: string): Promise<string> {
    try {
      // 尝试从package.json获取
      const packageJson = path.join(dir, "package.json");
      if (await fs.pathExists(packageJson)) {
        const pkg = await fs.readJson(packageJson);
        return pkg.version || "unknown";
      }

      // 尝试从git获取
      const { stdout } = await execAsync(
        `cd ${dir} && git describe --tags --abbrev=0 || git rev-parse --short HEAD`,
      );
      return stdout.trim();
    } catch {
      return "unknown";
    }
  }

  /**
   * 获取当前部署版本
   */
  private async getCurrentVersion(deployPath: string): Promise<string> {
    const packageJson = path.join(deployPath, "package.json");
    if (await fs.pathExists(packageJson)) {
      const pkg = await fs.readJson(packageJson);
      return pkg.version || "unknown";
    }
    return "unknown";
  }

  /**
   * 获取GitHub最新版本
   */
  private async getGitLatestVersion(repo: string): Promise<string> {
    try {
      // 使用git ls-remote获取最新tag或commit
      const { stdout } = await execAsync(
        `git ls-remote --tags --sort="v:refname" https://github.com/${repo}.git | tail -n1`,
      );

      if (stdout) {
        const match = stdout.match(/refs\/tags\/(.+)/);
        if (match && match[1]) {
          return match[1].replace(/\^\{\}$/, "");
        }
      }

      // 如果没有tag，获取最新commit
      const { stdout: commitStdout } = await execAsync(
        `git ls-remote https://github.com/${repo}.git HEAD | cut -f1`,
      );
      return commitStdout.trim().substring(0, 7) || "unknown";
    } catch {
      return "unknown";
    }
  }

  /**
   * 获取最后修改时间
   */
  private async getLastModifiedTime(dir: string): Promise<string | null> {
    try {
      const stats = await fs.stat(dir);
      return stats.mtime.toISOString();
    } catch {
      return null;
    }
  }

  /**
   * 清理临时目录
   */
  private async cleanupTemp(tempDir: string): Promise<void> {
    try {
      await fs.remove(tempDir);
    } catch (error) {
      this.logger.warn(`清理临时目录失败: ${tempDir}`, error);
    }
  }
}
```

## 2. 极简控制器

### `src/upgrade/upgrade.controller.ts`

```typescript
import { Controller, Get, Post, Body, Query } from "@nestjs/common";
import { UpgradeService } from "./upgrade.service";

@Controller("upgrade")
export class UpgradeController {
  constructor(private readonly upgradeService: UpgradeService) {}

  @Get("status")
  async getStatus() {
    return {
      timestamp: new Date().toISOString(),
      modules: await this.upgradeService.getModulesStatus(),
    };
  }

  @Post("upgrade")
  async upgrade(@Body() body: { module?: string; modules?: string[] }) {
    if (body.module) {
      return await this.upgradeService.upgradeModule(body.module);
    } else if (body.modules) {
      return await this.upgradeService.batchUpgrade(body.modules);
    } else {
      return await this.upgradeService.batchUpgrade();
    }
  }

  @Get("log")
  async getLog(@Query("module") module?: string) {
    // 返回升级日志
    return {
      timestamp: new Date().toISOString(),
      logs: [], // 可扩展为从文件读取日志
    };
  }
}
```

## 3. 创建目录的批处理脚本

### `create-upgrade-dirs.sh` (Linux/Mac)

```bash
#!/bin/bash

set -e

echo "创建升级模块目录结构..."

# 基础目录
BASE_DIR=$(pwd)

# 创建部署目录
echo "创建部署目录..."
sudo mkdir -p /var/www/deployments

# 创建微前端目录
echo "创建微前端目录..."
sudo mkdir -p /var/www/deployments/microfrontends
sudo mkdir -p /var/www/deployments/microfrontends/admin
sudo mkdir -p /var/www/deployments/microfrontends/user
sudo mkdir -p /var/www/deployments/microfrontends/dashboard

# 创建微服务目录
echo "创建微服务目录..."
sudo mkdir -p /var/www/deployments/services
sudo mkdir -p /var/www/deployments/services/auth
sudo mkdir -p /var/www/deployments/services/order
sudo mkdir -p /var/www/deployments/services/user

# 创建备份目录
echo "创建备份目录..."
sudo mkdir -p /var/www/backups

# 创建临时目录
echo "创建临时目录..."
sudo mkdir -p /tmp/upgrade

# 设置权限
echo "设置目录权限..."
sudo chmod 755 /var/www/deployments
sudo chmod 755 /var/www/backups
sudo chmod 777 /tmp/upgrade

# 创建项目目录
echo "创建项目目录..."
mkdir -p $BASE_DIR/src/upgrade
mkdir -p $BASE_DIR/config

# 创建配置文件
echo "创建配置文件..."
cat > $BASE_DIR/config/modules.json << EOF
[
  {
    "name": "microfrontend-admin",
    "repo": "your-org/admin-app",
    "type": "microfrontend",
    "deployPath": "/var/www/deployments/microfrontends/admin",
    "buildCommand": "npm run build"
  },
  {
    "name": "microfrontend-user",
    "repo": "your-org/user-app",
    "type": "microfrontend",
    "deployPath": "/var/www/deployments/microfrontends/user",
    "buildCommand": "npm run build"
  },
  {
    "name": "auth-service",
    "repo": "your-org/auth-service",
    "type": "backend",
    "deployPath": "/var/www/deployments/services/auth",
    "buildCommand": "npm run build"
  },
  {
    "name": "order-service",
    "repo": "your-org/order-service",
    "type": "backend",
    "deployPath": "/var/www/deployments/services/order",
    "buildCommand": "npm run build"
  }
]
EOF

# 创建环境文件
echo "创建环境文件..."
cat > $BASE_DIR/.env << EOF
# GitHub配置
GITHUB_TOKEN=your_token_here

# 部署配置
DEPLOYMENT_BASE=/var/www/deployments
BACKUP_BASE=/var/www/backups
TEMP_BASE=/tmp/upgrade

# 日志配置
LOG_LEVEL=info
LOG_FILE=/var/log/upgrade.log
EOF

# 创建简单的启动脚本
echo "创建启动脚本..."
cat > $BASE_DIR/start.sh << 'EOF'
#!/bin/bash

# 启动升级服务
echo "正在启动升级服务..."

# 设置环境变量
if [ -f .env ]; then
  export $(cat .env | grep -v '^#' | xargs)
fi

# 启动服务
npm run start:dev
EOF

chmod +x $BASE_DIR/start.sh

echo "目录创建完成！"
echo ""
echo "已创建以下目录："
echo "1. 部署目录: /var/www/deployments"
echo "2. 备份目录: /var/www/backups"
echo "3. 临时目录: /tmp/upgrade"
echo "4. 项目目录: $BASE_DIR"
echo ""
echo "下一步："
echo "1. 编辑 .env 文件，配置GitHub Token"
echo "2. 安装依赖: npm install"
echo "3. 启动服务: ./start.sh"
```

### `create-upgrade-dirs.bat` (Windows)

```batch
@echo off
echo 创建升级模块目录结构...
echo.

REM 设置基础目录
set BASE_DIR=%cd%

REM 创建部署目录（需要管理员权限）
echo 创建部署目录...
mkdir C:\deployments 2>nul
mkdir C:\deployments\microfrontends 2>nul
mkdir C:\deployments\microfrontends\admin 2>nul
mkdir C:\deployments\microfrontends\user 2>nul
mkdir C:\deployments\microfrontends\dashboard 2>nul

mkdir C:\deployments\services 2>nul
mkdir C:\deployments\services\auth 2>nul
mkdir C:\deployments\services\order 2>nul
mkdir C:\deployments\services\user 2>nul

REM 创建备份目录
echo 创建备份目录...
mkdir C:\backups 2>nul

REM 创建临时目录
echo 创建临时目录...
mkdir C:\temp\upgrade 2>nul

REM 创建项目目录
echo 创建项目目录...
mkdir src\upgrade 2>nul
mkdir config 2>nul

REM 创建配置文件
echo 创建配置文件...
echo [ > config\modules.json
echo   { >> config\modules.json
echo     "name": "microfrontend-admin", >> config\modules.json
echo     "repo": "your-org/admin-app", >> config\modules.json
echo     "type": "microfrontend", >> config\modules.json
echo     "deployPath": "C:\\deployments\\microfrontends\\admin", >> config\modules.json
echo     "buildCommand": "npm run build" >> config\modules.json
echo   }, >> config\modules.json
echo   { >> config\modules.json
echo     "name": "microfrontend-user", >> config\modules.json
echo     "repo": "your-org/user-app", >> config\modules.json
echo     "type": "microfrontend", >> config\modules.json
echo     "deployPath": "C:\\deployments\\microfrontends\\user", >> config\modules.json
echo     "buildCommand": "npm run build" >> config\modules.json
echo   }, >> config\modules.json
echo   { >> config\modules.json
echo     "name": "auth-service", >> config\modules.json
echo     "repo": "your-org/auth-service", >> config\modules.json
echo     "type": "backend", >> config\modules.json
echo     "deployPath": "C:\\deployments\\services\\auth", >> config\modules.json
echo     "buildCommand": "npm run build" >> config\modules.json
echo   }, >> config\modules.json
echo   { >> config\modules.json
echo     "name": "order-service", >> config\modules.json
echo     "repo": "your-org/order-service", >> config\modules.json
echo     "type": "backend", >> config\modules.json
echo     "deployPath": "C:\\deployments\\services\\order", >> config\modules.json
echo     "buildCommand": "npm run build" >> config\modules.json
echo   } >> config\modules.json
echo ] >> config\modules.json

REM 创建环境文件
echo 创建环境文件...
echo # GitHub配置 > .env
echo GITHUB_TOKEN=your_token_here >> .env
echo. >> .env
echo # 部署配置 >> .env
echo DEPLOYMENT_BASE=C:\deployments >> .env
echo BACKUP_BASE=C:\backups >> .env
echo TEMP_BASE=C:\temp\upgrade >> .env
echo. >> .env
echo # 日志配置 >> .env
echo LOG_LEVEL=info >> .env
echo LOG_FILE=C:\logs\upgrade.log >> .env

REM 创建启动脚本
echo 创建启动脚本...
echo @echo off > start.bat
echo echo 正在启动升级服务... >> start.bat
echo echo. >> start.bat
echo REM 设置环境变量 >> start.bat
echo if exist .env ( >> start.bat
echo   for /f "tokens=1,2 delims==" %%a in (.env) do ( >> start.bat
echo     if not "%%a"==" " set %%a=%%b >> start.bat
echo   ) >> start.bat
echo ) >> start.bat
echo. >> start.bat
echo REM 启动服务 >> start.bat
echo npm run start:dev >> start.bat

echo.
echo 目录创建完成！
echo.
echo 已创建以下目录：
echo 1. 部署目录: C:\deployments
echo 2. 备份目录: C:\backups
echo 3. 临时目录: C:\temp\upgrade
echo 4. 项目目录: %BASE_DIR%
echo.
echo 下一步：
echo 1. 编辑 .env 文件，配置GitHub Token
echo 2. 安装依赖: npm install
echo 3. 启动服务: start.bat
echo.
pause
```

## 4. 极简的package.json

```json
{
  "name": "upgrade-module",
  "version": "1.0.0",
  "description": "极简程序升级模块",
  "main": "dist/main.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/main.js",
    "start:dev": "nest start --watch"
  },
  "dependencies": {
    "@nestjs/common": "^9.0.0",
    "@nestjs/core": "^9.0.0",
    "@nestjs/platform-express": "^9.0.0",
    "fs-extra": "^11.0.0",
    "reflect-metadata": "^0.1.13",
    "rxjs": "^7.0.0"
  },
  "devDependencies": {
    "@nestjs/cli": "^9.0.0",
    "@types/node": "^18.0.0",
    "typescript": "^4.7.0"
  }
}
```

## 5. 主模块

### `src/main.ts`

```typescript
import { NestFactory } from "@nestjs/core";
import { UpgradeModule } from "./upgrade/upgrade.module";

async function bootstrap() {
  const app = await NestFactory.create(UpgradeModule);

  // 允许跨域（如果需要）
  app.enableCors();

  await app.listen(3000);
  console.log(`升级服务已启动: http://localhost:3000`);
}

bootstrap();
```

### `src/upgrade/upgrade.module.ts`

```typescript
import { Module } from "@nestjs/common";
import { UpgradeController } from "./upgrade.controller";
import { UpgradeService } from "./upgrade.service";

@Module({
  controllers: [UpgradeController],
  providers: [UpgradeService],
})
export class UpgradeModule {}
```

## 6. 使用说明

### 6.1 初始化项目

```bash
# 1. 创建目录
./create-upgrade-dirs.sh  # Linux/Mac
# 或
create-upgrade-dirs.bat   # Windows

# 2. 安装依赖
npm install

# 3. 配置GitHub Token
# 编辑 .env 文件，将 GITHUB_TOKEN 替换为你的GitHub Personal Access Token
```

### 6.2 启动服务

```bash
npm run start:dev
```

### 6.3 API使用

#### 检查所有模块状态

```bash
curl http://localhost:3000/upgrade/status
```

#### 升级单个模块

```bash
curl -X POST http://localhost:3000/upgrade/upgrade \
  -H "Content-Type: application/json" \
  -d '{"module": "auth-service"}'
```

#### 批量升级模块

```bash
curl -X POST http://localhost:3000/upgrade/upgrade \
  -H "Content-Type: application/json" \
  -d '{"modules": ["auth-service", "order-service"]}'
```

#### 升级所有模块

```bash
curl -X POST http://localhost:3000/upgrade/upgrade \
  -H "Content-Type: application/json" \
  -d '{}'
```

## 7. 核心流程总结

这个极简升级模块的核心流程是：

1. **配置模块信息**：在代码中配置要升级的模块（GitHub仓库、部署路径、构建命令）
2. **触发升级**：通过API触发升级流程
3. **拉取代码**：从GitHub拉取最新代码到临时目录
4. **构建项目**：执行 `npm install` 和 `npm run build`
5. **部署文件**：将构建产物复制到部署目录
6. **返回结果**：返回升级成功/失败信息

## 8. 如果需要更灵活配置

如果希望配置文件更灵活，可以改为从JSON文件读取配置：

### `config/modules.json`

```json
[
  {
    "name": "microfrontend-admin",
    "repo": "your-org/admin-app",
    "type": "microfrontend",
    "deployPath": "/var/www/deployments/microfrontends/admin",
    "buildCommand": "npm run build",
    "branch": "main",
    "env": {
      "NODE_ENV": "production"
    }
  },
  {
    "name": "auth-service",
    "repo": "your-org/auth-service",
    "type": "backend",
    "deployPath": "/var/www/deployments/services/auth",
    "buildCommand": "npm run build:prod",
    "branch": "release",
    "beforeBuild": "npm run generate-types",
    "afterDeploy": "pm2 restart auth-service"
  }
]
```

然后在服务中读取这个配置文件：

```typescript
import * as modulesConfig from '../config/modules.json';

// 在构造函数中
constructor() {
  this.modules = modulesConfig;
}
```

这个实现非常简洁，只专注于核心的升级功能：从Git获取代码 → 构建 → 部署，非常适合后台自动化升级场景。
