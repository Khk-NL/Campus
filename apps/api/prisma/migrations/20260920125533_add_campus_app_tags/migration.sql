-- CreateEnum
CREATE TYPE "TagStatus" AS ENUM ('active', 'merged', 'deprecated');

-- CreateTable
CREATE TABLE "campus_app_tags" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "normalized_name" TEXT NOT NULL,
    "status" "TagStatus" NOT NULL DEFAULT 'active',
    "merged_into_id" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "campus_app_tags_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "campus_app_tag_aliases" (
    "id" TEXT NOT NULL,
    "normalized_alias" TEXT NOT NULL,
    "tag_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "campus_app_tag_aliases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "campus_app_tag_links" (
    "app_id" TEXT NOT NULL,
    "tag_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "campus_app_tag_links_pkey" PRIMARY KEY ("app_id","tag_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "campus_app_tags_normalized_name_key" ON "campus_app_tags"("normalized_name");

-- CreateIndex
CREATE INDEX "campus_app_tags_status_idx" ON "campus_app_tags"("status");

-- CreateIndex
CREATE UNIQUE INDEX "campus_app_tag_aliases_normalized_alias_key" ON "campus_app_tag_aliases"("normalized_alias");

-- CreateIndex
CREATE INDEX "campus_app_tag_aliases_tag_id_idx" ON "campus_app_tag_aliases"("tag_id");

-- CreateIndex
CREATE INDEX "campus_app_tag_links_tag_id_idx" ON "campus_app_tag_links"("tag_id");

-- AddForeignKey
ALTER TABLE "campus_app_tags" ADD CONSTRAINT "campus_app_tags_merged_into_id_fkey" FOREIGN KEY ("merged_into_id") REFERENCES "campus_app_tags"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_tag_aliases" ADD CONSTRAINT "campus_app_tag_aliases_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "campus_app_tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_tag_links" ADD CONSTRAINT "campus_app_tag_links_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "campus_apps"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_tag_links" ADD CONSTRAINT "campus_app_tag_links_tag_id_fkey" FOREIGN KEY ("tag_id") REFERENCES "campus_app_tags"("id") ON DELETE CASCADE ON UPDATE CASCADE;
