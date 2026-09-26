migrate((app) => {
  const settings = app.settings();
  settings.meta.appName = "Campulse";
  settings.meta.senderName = "Campulse";
  app.save(settings);
  // Update only the project's own known seed records, never user-authored content.
  for (const record of app.findRecordsByFilter("campus_content", "demo = true", "", 1000)) {
    const payload = record.get("payload");
    if (!payload || typeof payload !== "object") continue;
    for (const field of ["name", "description", "title", "body", "developerName", "sourceName"]) {
      if (typeof payload[field] === "string") payload[field] = payload[field].replace(/\bCampus\b/g, "Campulse");
    }
    record.set("payload", payload);
    app.save(record);
  }
}, (app) => {});
