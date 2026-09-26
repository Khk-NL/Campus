migrate((app) => {
  const settings = app.settings();
  settings.smtp.enabled = false; // Enable after entering real Brevo credentials.
  settings.smtp.host = "smtp-relay.brevo.com";
  settings.smtp.port = 465;
  settings.smtp.tls = true;
  settings.smtp.authMethod = "PLAIN";
  app.save(settings);
}, (app) => {
  // Do not restore an obsolete provider or remove credentials on rollback.
});
