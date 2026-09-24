migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const ownerRule = '@request.auth.id != "" && owner = @request.auth.id';
  const collection = new Collection({
    type: "base",
    name: "course_notes",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: ownerRule + ' && @request.body.owner:changed = false',
    deleteRule: ownerRule,
    fields: [
      { name: "owner", type: "relation", required: true,
        collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "courseId", type: "text", required: true },
      { name: "title", type: "text", required: true },
      { name: "content", type: "text" },
      { name: "schemaVersion", type: "number", required: true, min: 1 },
    ],
    indexes: [
      "CREATE INDEX idx_course_notes_owner_course ON course_notes (owner, courseId)",
    ],
  });
  app.save(collection);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("course_notes"));
});
