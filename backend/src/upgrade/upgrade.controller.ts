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
