migrate((app) => {
  const users = app.findCollectionByNameOrId('users');
  const owner = '@request.auth.id != "" && owner = @request.auth.id';
  app.save(new Collection({
    name: 'user_favorites', type: 'base', listRule: owner, viewRule: owner,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: owner + ' && @request.body.owner:changed = false', deleteRule: owner,
    fields: [
      { name: 'owner', type: 'relation', required: true, collectionId: users.id, maxSelect: 1, cascadeDelete: true },
      { name: 'board', type: 'text', required: true, max: 100 },
      { name: 'entryKey', type: 'text', required: true, max: 200 },
      { name: 'created', type: 'autodate', onCreate: true },
      { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
    ],
    indexes: ['CREATE UNIQUE INDEX idx_user_favorites_entry ON user_favorites (owner, board, entryKey)'],
  }));
  const content = app.findCollectionByNameOrId('campus_content');
  content.fields.add(new RelationField({ name: 'owner', collectionId: users.id, maxSelect: 1, cascadeDelete: true }));
  content.listRule = content.viewRule = '(published = true && ((owner = "" && kind != "task") || (@request.auth.id != "" && owner = @request.auth.id)))';
  app.save(content);
}, (app) => {
  const content = app.findCollectionByNameOrId('campus_content');
  content.fields.removeByName('owner');
  content.listRule = content.viewRule = 'published = true';
  app.save(content);
  app.delete(app.findCollectionByNameOrId('user_favorites'));
});
