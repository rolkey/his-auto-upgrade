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
