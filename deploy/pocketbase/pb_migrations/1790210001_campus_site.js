// Deployment-specific public metadata. No passwords or API keys belong here.
migrate((app) => {
  const settings = app.settings();
  settings.meta.appName = "Campus";
  settings.meta.appURL = "https://campus.allezafrique.cn";
  settings.meta.senderName = "Campus";
  settings.meta.senderAddress = "kongb3124@qq.com";
  app.save(settings);
}, (app) => {
  // Keep deployment metadata when rolling back collection migrations.
});
