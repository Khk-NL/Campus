migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const ownerRule = '@request.auth.id != "" && owner = @request.auth.id';
  const collection = new Collection({
    type: "base",
    name: "course_review_cards",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: ownerRule + ' && @request.body.owner:changed = false',
    deleteRule: ownerRule,
    fields: [
      { name: "owner", type: "relation", required: true,
        collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "courseId", type: "text", required: true },
      { name: "noteId", type: "text" },
      { name: "front", type: "text", required: true },
      { name: "back", type: "text", required: true },
      { name: "due", type: "date", required: true },
      { name: "scheduler", type: "json" },
      { name: "reviewHistory", type: "json" },
      { name: "created", type: "autodate", onCreate: true },
      { name: "updated", type: "autodate", onCreate: true, onUpdate: true },
    ],
    indexes: [
      "CREATE INDEX idx_review_cards_owner_course_due ON course_review_cards (owner, courseId, due)",
    ],
  });
  app.save(collection);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("course_review_cards"));
});
