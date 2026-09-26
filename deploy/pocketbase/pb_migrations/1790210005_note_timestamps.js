migrate((app) => {
  const collection = app.findCollectionByNameOrId("course_notes");
  if (!collection.fields.getByName("created")) {
    collection.fields.add(new AutodateField({ name: "created", onCreate: true }));
  }
  if (!collection.fields.getByName("updated")) {
    collection.fields.add(new AutodateField({ name: "updated", onCreate: true, onUpdate: true }));
  }
  app.save(collection);
  // Earlier records have no recoverable timestamp; leave them blank rather than invent history.
}, (app) => {});
