import { Injectable, Logger } from '@nestjs/common';
import { exec } from 'child_process';
import { promisify } from 'util';
import { promises as fs, constants, existsSync } from 'node:fs';
import * as path from 'node:path';
import * as modulesConfig from '../config/modules.json';

const execAsync = promisify(exec);

export interface ModuleConfig {
  name: string;
  repo: string; // GitHub仓库地址，格式：owner/repo
  type: 'frontend' | 'backend' | 'microfrontend';
  deployPath: string; // 部署目标路径
  buildCommand: string; // 构建命令，默认 'npm run build'
  branch?: string; // 分支，默认 'main'
}

export interface UpgradeResult {
  success: boolean;
  module: string;
  message: string;
  timestamp: string;
  version?: string;
}

export interface ModuleStatus {
  name: string;
  type: 'frontend' | 'backend' | 'microfrontend';
  currentVersion: string;
  latestVersion: string;
  deployPath: string;
  status: 'up-to-date' | 'outdated';
  lastUpdated: string | null;
}

export interface PackageJson {
  version?: string;
  [key: string]: any;
}

@Injectable()
export class UpgradeService {
  private readonly logger = new Logger(UpgradeService.name);
  private readonly modules = modulesConfig as ModuleConfig[];

  constructor() {}

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

    const tempDir = path.join('/tmp/upgrade', moduleName);
    const startTime = Date.now();

    try {
      this.logger.log(`开始升级模块: ${moduleName}`);

      // 1. 创建临时目录
      await fs.mkdir(tempDir, { recursive: true });

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
      throw error;
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
  async getModulesStatus(): Promise<ModuleStatus[]> {
    const statusList: ModuleStatus[] = [];

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
          status: currentVersion === latestVersion ? 'up-to-date' : 'outdated',
          lastUpdated: await this.getLastModifiedTime(module.deployPath),
        });
      } catch (error) {
        console.error('getModulesStatus', error);
        throw error;
      }
    }

    return statusList;
  }

  /**
   * 从GitHub克隆或拉取代码
   */
  private async gitCloneOrPull(module: ModuleConfig, targetDir: string): Promise<void> {
    const repoUrl = `https://github.com/${module.repo}.git`;
    const branch = module.branch || 'main';

    const gitDir = path.join(targetDir, '.git');

    if (existsSync(gitDir)) {
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
    const packageJson = path.join(dir, 'package.json');

    try {
      await fs.access(packageJson, constants.F_OK);
      await execAsync(`cd ${dir} && npm ci --no-audit --no-fund`);
    } catch {
      // package.json 不存在，跳过安装
    }
  }

  /**
   * 构建项目
   */
  private async buildProject(dir: string, buildCommand: string): Promise<void> {
    await execAsync(`cd ${dir} && ${buildCommand}`, {
      maxBuffer: 1024 * 1024 * 10,
    });
  }

  /**
   * 备份当前部署
   */
  private async backupCurrent(deployPath: string, moduleName: string): Promise<void> {
    try {
      await fs.access(deployPath, constants.F_OK);
      const backupDir = path.join(
        '/var/www/backups',
        moduleName,
        new Date().toISOString().replace(/:/g, '-'),
      );
      await fs.mkdir(path.dirname(backupDir), { recursive: true });
      await fs.cp(deployPath, backupDir, { recursive: true });
    } catch {
      // deployPath 不存在，跳过备份
    }
  }

  /**
   * 部署构建产物
   */
  private async deployBuild(
    sourceDir: string,
    targetDir: string,
    type: 'frontend' | 'backend' | 'microfrontend',
  ): Promise<void> {
    // 查找构建输出目录
    let buildOutput = '';

    if (type === 'frontend' || type === 'microfrontend') {
      // 前端项目通常输出到 dist 或 build 目录
      const possibleDirs = ['dist', 'build', 'out', 'public'];
      for (const dir of possibleDirs) {
        const testPath = path.join(sourceDir, dir);
        try {
          await fs.access(testPath, constants.F_OK);
          buildOutput = testPath;
          break;
        } catch {
          // 目录不存在，继续尝试下一个
        }
      }
    } else {
      // 后端项目可能输出到 dist 目录，也可能是整个项目
      const distPath = path.join(sourceDir, 'dist');
      try {
        await fs.access(distPath, constants.F_OK);
        buildOutput = distPath;
      } catch {
        buildOutput = sourceDir;
      }
    }

    if (!buildOutput) {
      throw new Error('未找到构建输出目录');
    }

    // 清空目标目录（如果存在）
    try {
      await fs.access(targetDir, constants.F_OK);
      await fs.rm(targetDir, { recursive: true, force: true });
    } catch {
      // 目录不存在，继续创建
    }

    // 创建目标目录
    await fs.mkdir(targetDir, { recursive: true });

    // 复制构建产物
    await fs.cp(buildOutput, targetDir, { recursive: true });
  }

  /**
   * 获取版本号
   */
  private async getVersion(dir: string): Promise<string> {
    try {
      // 尝试从package.json获取
      const packageJson = path.join(dir, 'package.json');
      await fs.access(packageJson, constants.F_OK);
      const pkg = JSON.parse(await fs.readFile(packageJson, 'utf-8')) as PackageJson;
      return pkg.version || 'unknown';
    } catch {
      try {
        // 尝试从git获取
        const { stdout } = await execAsync(
          `cd ${dir} && git describe --tags --abbrev=0 || git rev-parse --short HEAD`,
        );
        return stdout.trim();
      } catch {
        return 'unknown';
      }
    }
  }

  /**
   * 获取当前部署版本
   */
  private async getCurrentVersion(deployPath: string): Promise<string> {
    try {
      const packageJson = path.join(deployPath, 'package.json');
      await fs.access(packageJson, constants.F_OK);
      const pkg = JSON.parse(await fs.readFile(packageJson, 'utf-8')) as PackageJson;
      return pkg.version || 'unknown';
    } catch {
      return 'unknown';
    }
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
          return match[1].replace(/\^\{\}$/, '');
        }
      }

      // 如果没有tag，获取最新commit
      const { stdout: commitStdout } = await execAsync(
        `git ls-remote https://github.com/${repo}.git HEAD | cut -f1`,
      );
      return commitStdout.trim().substring(0, 7) || 'unknown';
    } catch {
      return 'unknown';
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
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (error) {
      this.logger.warn(`清理临时目录失败: ${tempDir}`, error);
    }
  }
}
