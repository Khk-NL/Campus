migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const ownerRule = '@request.auth.id != "" && owner = @request.auth.id';
  const collection = new Collection({
    type: "base",
    name: "user_courses",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: ownerRule + ' && @request.body.owner:changed = false',
    deleteRule: ownerRule,
    fields: [
      { name: "owner", type: "relation", required: true,
        collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "payload", type: "json", required: true },
      { name: "schemaVersion", type: "number", required: true, min: 1 },
    ],
    indexes: ["CREATE INDEX idx_user_courses_owner ON user_courses (owner)"],
  });
  app.save(collection);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("user_courses"));
});
