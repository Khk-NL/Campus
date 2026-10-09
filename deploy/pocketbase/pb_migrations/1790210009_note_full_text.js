migrate((app) => {
  const notes = app.findCollectionByNameOrId('course_notes');
  // PocketBase's implicit 5000-char default blocked Markdown textbook imports.
  notes.fields.getByName('content').max = 2 * 1024 * 1024;
  app.save(notes);
}, (app) => {
  const notes = app.findCollectionByNameOrId('course_notes');
  notes.fields.getByName('content').max = 5000;
  app.save(notes);
});
