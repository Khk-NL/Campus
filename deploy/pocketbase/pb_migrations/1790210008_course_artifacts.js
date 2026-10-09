migrate((app) => {
  const owner = '@request.auth.id != "" && owner = @request.auth.id';
  app.save(new Collection({
    name: 'course_artifacts', type: 'base', listRule: owner, viewRule: owner,
    createRule: '@request.auth.id != "" && @request.body.owner = @request.auth.id',
    updateRule: owner + ' && @request.body.owner:changed = false && @request.body.courseId:changed = false',
    deleteRule: owner,
    fields: [
      { name: 'owner', type: 'relation', required: true, collectionId: app.findCollectionByNameOrId('users').id, maxSelect: 1, cascadeDelete: true },
      { name: 'courseId', type: 'text', required: true, max: 100 },
      { name: 'kind', type: 'select', required: true, maxSelect: 1, values: ['quiz', 'flashcards', 'mindmap', 'conversation'] },
      { name: 'title', type: 'text', required: true, max: 200 },
      { name: 'payload', type: 'json', required: true, maxSize: 524288 },
      { name: 'created', type: 'autodate', onCreate: true },
      { name: 'updated', type: 'autodate', onCreate: true, onUpdate: true },
    ],
    indexes: ['CREATE INDEX idx_artifacts_course_owner ON course_artifacts (owner, courseId, created)'],
  }));
}, (app) => { app.delete(app.findCollectionByNameOrId('course_artifacts')); });
