import { Controller, Get, Post, Body, Query } from '@nestjs/common';
import { ModuleStatus, UpgradeResult, UpgradeService } from './upgrade.service';

@Controller('upgrade')
export class UpgradeController {
  constructor(private readonly upgradeService: UpgradeService) {}

  @Get('status')
  async getStatus(): Promise<{ timestamp: string; modules: ModuleStatus[] }> {
    return {
      timestamp: new Date().toISOString(),
      modules: await this.upgradeService.getModulesStatus(),
    };
  }

  @Post('upgrade')
  async upgrade(
    @Body() body: { module?: string; modules?: string[] },
  ): Promise<UpgradeResult | UpgradeResult[]> {
    if (body.module) {
      return await this.upgradeService.upgradeModule(body.module);
    } else if (body.modules) {
      return await this.upgradeService.batchUpgrade(body.modules);
    } else {
      return await this.upgradeService.batchUpgrade();
    }
  }

  @Get('log')
  getLog(@Query('module') module?: string) {
    console.log(module);
    // 返回升级日志
    return {
      timestamp: new Date().toISOString(),
      logs: [], // 可扩展为从文件读取日志
    };
  }
}
