-- AlterTable
ALTER TABLE "campus_apps" ADD COLUMN     "open_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "campus_app_likes" (
    "id" TEXT NOT NULL,
    "app_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "campus_app_likes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "campus_app_likes_user_id_idx" ON "campus_app_likes"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "campus_app_likes_app_id_user_id_key" ON "campus_app_likes"("app_id", "user_id");

-- AddForeignKey
ALTER TABLE "campus_app_likes" ADD CONSTRAINT "campus_app_likes_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "campus_apps"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_likes" ADD CONSTRAINT "campus_app_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
