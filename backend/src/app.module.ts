import { Module } from '@nestjs/common';
import { UpgradeModule } from './upgrade/upgrade.module';

@Module({
  imports: [UpgradeModule],
})
export class AppModule {}
