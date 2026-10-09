migrate((app) => {
  const users = app.findCollectionByNameOrId('users').id;
  const signed = '@request.auth.id != "" && @request.auth.verified = true';
  const owner = signed + ' && owner = @request.auth.id';
  const dates = () => [
    { name: 'created', type: 'autodate', onCreate: true },
    { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
  ];
  const ownership = () => ({ name: 'owner', type: 'relation', required: true, collectionId: users, maxSelect: 1, cascadeDelete: true });
  const repositories = new Collection({
    name: 'forge_repositories', type: 'base',
    listRule: 'visibility = "public" || owner = @request.auth.id',
    viewRule: 'visibility = "public" || owner = @request.auth.id',
    createRule: signed + ' && @request.body.owner = @request.auth.id',
    updateRule: owner + ' && @request.body.owner:changed = false', deleteRule: owner,
    fields: [ownership(),
      { name: 'name', type: 'text', required: true, max: 100 },
      { name: 'summary', type: 'text', max: 500 },
      { name: 'readme', type: 'text', max: 100000 },
      { name: 'topics', type: 'text', max: 300 },
      { name: 'visibility', type: 'select', required: true, maxSelect: 1, values: ['public', 'private'] },
      ...dates()],
    indexes: ['CREATE INDEX idx_forge_repository_owner ON forge_repositories (owner, updated)'],
  });
  app.save(repositories);
  const repo = () => ({ name: 'repository', type: 'relation', required: true, collectionId: repositories.id, maxSelect: 1, cascadeDelete: true });
  const readable = '(repository.visibility = "public" || repository.owner = @request.auth.id)';
  const discussions = new Collection({
    name: 'forge_discussions', type: 'base', listRule: readable, viewRule: readable,
    createRule: signed + ' && @request.body.owner = @request.auth.id && ' + readable,
    updateRule: signed + ' && ' + readable + ' && (owner = @request.auth.id || repository.owner = @request.auth.id) && @request.body.owner:changed = false && @request.body.repository:changed = false',
    deleteRule: owner + ' || (' + signed + ' && repository.owner = @request.auth.id)',
    fields: [ownership(), repo(),
      { name: 'title', type: 'text', required: true, max: 200 },
      { name: 'body', type: 'text', required: true, max: 20000 },
      { name: 'kind', type: 'select', required: true, maxSelect: 1, values: ['question', 'idea', 'bug', 'update'] },
      { name: 'status', type: 'select', required: true, maxSelect: 1, values: ['open', 'closed'] },
      ...dates()],
    indexes: ['CREATE INDEX idx_forge_discussion_repository ON forge_discussions (repository, created)'],
  });
  app.save(discussions);
  const threadReadable = '(discussion.repository.visibility = "public" || discussion.repository.owner = @request.auth.id)';
  app.save(new Collection({
    name: 'forge_replies', type: 'base', listRule: threadReadable, viewRule: threadReadable,
    createRule: signed + ' && @request.body.owner = @request.auth.id && discussion.status = "open" && ' + threadReadable,
    updateRule: owner + ' && ' + threadReadable + ' && @request.body.owner:changed = false && @request.body.discussion:changed = false',
    deleteRule: owner + ' || (' + signed + ' && discussion.repository.owner = @request.auth.id)',
    fields: [ownership(),
      { name: 'discussion', type: 'relation', required: true, collectionId: discussions.id, maxSelect: 1, cascadeDelete: true },
      { name: 'body', type: 'text', required: true, max: 20000 }, ...dates()],
    indexes: ['CREATE INDEX idx_forge_reply_discussion ON forge_replies (discussion, created)'],
  }));
  app.save(new Collection({
    name: 'forge_stars', type: 'base', listRule: readable, viewRule: readable,
    createRule: signed + ' && @request.body.owner = @request.auth.id && ' + readable,
    updateRule: null, deleteRule: owner,
    fields: [ownership(), repo(), ...dates()],
    indexes: ['CREATE UNIQUE INDEX idx_forge_star_unique ON forge_stars (owner, repository)'],
  }));
}, (app) => {
  for (const name of ['forge_stars', 'forge_replies', 'forge_discussions', 'forge_repositories']) {
    app.delete(app.findCollectionByNameOrId(name));
  }
});
