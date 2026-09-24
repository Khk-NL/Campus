migrate((app) => {
  const collection = new Collection({
    type: "base",
    name: "campus_content",
    listRule: "published = true",
    viewRule: "published = true",
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      { name: "kind", type: "text", required: true },
      { name: "universityId", type: "text", required: true },
      { name: "payload", type: "json", required: true },
      { name: "schemaVersion", type: "number", required: true, min: 1 },
      { name: "published", type: "bool" },
      { name: "demo", type: "bool" },
    ],
    indexes: [
      "CREATE INDEX idx_campus_content_kind_university ON campus_content (kind, universityId)",
    ],
  });
  app.save(collection);

  function seed(kind, payload) {
    const record = new Record(collection);
    record.set("kind", kind);
    record.set("universityId", "ecnu");
    record.set("payload", payload);
    record.set("schemaVersion", 1);
    record.set("published", true);
    record.set("demo", true);
    app.save(record);
  }

  seed("university", {
    name: "华东师范大学", shortName: "ECNU", domain: "ecnu.edu.cn",
    status: "active", config: {
      termWeeks: 18, periodsPerDay: 13, weekStartsOn: "monday",
      timezone: "Asia/Shanghai", locales: ["zh", "en"],
      capabilities: ["services"], firstPeriodStart: "08:00", periodMinutes: 45,
    },
  });
  seed("service", {
    name: "学校官网", description: "华东师范大学官方网站",
    category: "official-hub", type: "web", origin: "official",
    sourceSystem: "manual", sourceId: "mvp:ecnu-home", isOfficial: true,
    status: "active", tags: ["学校", "官网"],
    launchTarget: { type: "web", url: "https://www.ecnu.edu.cn/" },
  });
  seed("service", {
    name: "开放平台", description: "华东师范大学开放平台入口",
    category: "academic", type: "web", origin: "official",
    sourceSystem: "manual", sourceId: "mvp:ecnu-developer", isOfficial: true,
    status: "active", tags: ["开放平台", "开发者"],
    launchTarget: { type: "web", url: "https://developer.ecnu.edu.cn/" },
  });
  seed("course", {
    name: "Campus 示例课程", teacher: "演示教师", location: "演示教室",
    startWeek: 1, endWeek: 18, weekday: 1, startPeriod: 1, endPeriod: 2,
    scheduleRule: "周一 1–2 节（演示）",
  });
  seed("app", {
    name: "Campus 项目主页", description: "Campus 项目代码与说明",
    developerName: "Campus", origin: "open-source", universityScope: "all-universities",
    permissions: [], tags: ["校园", "开源"],
    launchTarget: { type: "web", url: "https://github.com/Khk-NL/Campus" },
  });
  seed("announcement", {
    title: "Campus MVP 演示", body: "本条为演示公告，不代表学校通知。",
    priority: "normal", publishedAt: new Date().toISOString(), sourceName: "Campus 演示",
  });
}, (app) => {
  app.delete(app.findCollectionByNameOrId("campus_content"));
});
