migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  const ownerRule = '@request.auth.id != "" && owner = @request.auth.id';
  const collection = new Collection({
    type: "base",
    name: "study_workspaces",
    listRule: ownerRule,
    viewRule: ownerRule,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: ownerRule + ' && @request.body.owner:changed = false',
    deleteRule: null,
    fields: [
      { name: "owner", type: "relation", required: true,
        collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: "payload", type: "json", required: true },
    ],
    indexes: ["CREATE UNIQUE INDEX idx_study_workspaces_owner ON study_workspaces (owner)"],
  });
  app.save(collection);
}, (app) => {
  app.delete(app.findCollectionByNameOrId("study_workspaces"));
});
