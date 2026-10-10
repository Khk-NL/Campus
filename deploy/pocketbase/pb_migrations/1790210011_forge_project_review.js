migrate((app) => {
  const projects = app.findCollectionByNameOrId('forge_repositories');
  projects.fields.add(new SelectField({ name: 'reviewState', maxSelect: 1, values: ['draft', 'pending', 'approved', 'rejected'] }));
  projects.fields.add(new TextField({ name: 'schoolProof', max: 2000 }));
  projects.fields.add(new TextField({ name: 'reviewNote', max: 2000 }));
  projects.fields.add(new BoolField({ name: 'schoolVerified' }));
  projects.fields.add(new TextField({ name: 'universityId', max: 50 }));
  projects.fields.add(new TextField({ name: 'repositoryUrl', max: 500, pattern: '^https://github[.]com/[A-Za-z0-9_-]+/[A-Za-z0-9_.-]+/?$' }));
  const signed = '@request.auth.id != "" && @request.auth.verified = true';
  const shared = 'visibility = "public" && reviewState = "approved" && schoolVerified = true && universityId = "ecnu"';
  projects.listRule = projects.viewRule = '(' + shared + ') || owner = @request.auth.id';
  projects.createRule = signed + ' && @request.body.owner = @request.auth.id && (@request.body.reviewState = "draft" || @request.body.reviewState = "pending") && @request.body.schoolVerified = false && @request.body.reviewNote = "" && @request.body.universityId = "ecnu"';
  // Editing an approved project always resubmits it. Only superusers can approve.
  projects.updateRule = signed + ' && owner = @request.auth.id && @request.body.owner:changed = false && (@request.body.reviewState = "draft" || @request.body.reviewState = "pending") && @request.body.schoolVerified:changed = false && @request.body.reviewNote:changed = false && @request.body.universityId:changed = false';
  app.save(projects);
  // Existing submissions join the queue; migration grants no automatic approvals.
  app.db().newQuery('UPDATE forge_repositories SET reviewState = {:state}, universityId = {:school}').bind({ state: 'draft', school: 'ecnu' }).execute();
  const readable = '((repository.visibility = "public" && repository.reviewState = "approved" && repository.schoolVerified = true && repository.universityId = "ecnu") || repository.owner = @request.auth.id)';
  for (const name of ['forge_discussions', 'forge_stars']) {
    const collection = app.findCollectionByNameOrId(name);
    collection.listRule = collection.viewRule = readable;
    collection.createRule = signed + ' && @request.body.owner = @request.auth.id && ' + readable;
    if (name === 'forge_discussions') collection.updateRule = signed + ' && ' + readable + ' && (owner = @request.auth.id || repository.owner = @request.auth.id) && @request.body.owner:changed = false && @request.body.repository:changed = false';
    app.save(collection);
  }
  const replies = app.findCollectionByNameOrId('forge_replies');
  const threadReadable = readable.replace(/repository\./g, 'discussion.repository.');
  replies.listRule = replies.viewRule = threadReadable;
  replies.createRule = signed + ' && @request.body.owner = @request.auth.id && discussion.status = "open" && ' + threadReadable;
  replies.updateRule = signed + ' && owner = @request.auth.id && ' + threadReadable + ' && @request.body.owner:changed = false && @request.body.discussion:changed = false';
  app.save(replies);
}, (app) => {
  // Rollback retains the moderation boundary. Restoring older visibility rules
  // would expose pending submissions; deploy a reviewed forward migration instead.
  throw new Error('Project review migration requires a reviewed forward rollback');
});
