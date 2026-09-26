// Apply only after campus.scsldr.cn DNS and HTTPS are available.
migrate((app) => {
  const settings = app.settings();
  settings.meta.appURL = "https://campus.scsldr.cn";
  app.save(settings);
}, (app) => {
  const settings = app.settings();
  settings.meta.appURL = "https://campus.allezafrique.cn";
  app.save(settings);
});
