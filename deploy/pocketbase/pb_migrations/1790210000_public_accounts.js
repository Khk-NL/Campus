// Production-only account policy. Copy alongside the base migrations to a NEW
// production PocketBase instance; do not apply to the local pilot database.
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");
  users.listRule = "id = @request.auth.id";
  users.viewRule = "id = @request.auth.id";
  users.createRule = ""; // anonymous email sign-up
  users.updateRule = "id = @request.auth.id && @request.body.verified:changed = false && @request.body.email:changed = false";
  users.deleteRule = null;
  users.authRule = "verified = true";
  users.manageRule = null;
  users.passwordAuth = { enabled: true, identityFields: ["email"] };
  app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.createRule = null;
  users.authRule = "";
  app.save(users);
});
