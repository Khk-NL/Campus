migrate((app) => {
  const collection = app.findCollectionByNameOrId("course_notes");
  if (!collection.fields.getByName("attachment")) {
    collection.fields.add(new FileField({
      name: "attachment",
      maxSelect: 1,
      maxSize: 20 * 1024 * 1024,
      mimeTypes: ["application/pdf"],
      protected: true,
    }));
  }
  app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("course_notes");
  collection.fields.removeByName("attachment");
  app.save(collection);
});
