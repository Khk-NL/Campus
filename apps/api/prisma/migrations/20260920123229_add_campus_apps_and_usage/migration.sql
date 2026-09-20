-- CreateEnum
CREATE TYPE "CampusAppType" AS ENUM ('web', 'github_pages', 'website', 'wechat_mini_program', 'native_app', 'external_project');

-- CreateEnum
CREATE TYPE "CampusAppOrigin" AS ENUM ('official', 'student_developed', 'external', 'open_source');

-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('draft', 'pending_review', 'approved', 'rejected', 'suspended');

-- CreateTable
CREATE TABLE "campus_apps" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "icon_url" TEXT,
    "type" "CampusAppType" NOT NULL,
    "origin" "CampusAppOrigin" NOT NULL,
    "scope_all" BOOLEAN NOT NULL DEFAULT false,
    "scope_university_ids" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "repository_url" TEXT,
    "source_url" TEXT,
    "submitter_id" TEXT,
    "developer_id" TEXT,
    "status" "ReviewStatus" NOT NULL DEFAULT 'draft',
    "target_type" "LaunchTargetType" NOT NULL,
    "launch_url" TEXT,
    "launch_preferred_mode" TEXT,
    "launch_original_id" TEXT,
    "launch_path" TEXT,
    "launch_scheme" TEXT,
    "launch_fallback_url" TEXT,
    "launch_store_url" TEXT,
    "launch_app_id" TEXT,
    "launch_route" TEXT,
    "permissions" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "screenshots" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "version" TEXT NOT NULL DEFAULT '0.0.0',
    "install_count" INTEGER NOT NULL DEFAULT 0,
    "last_verified_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "campus_apps_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "campus_app_usage" (
    "id" TEXT NOT NULL,
    "app_id" TEXT NOT NULL,
    "user_id" TEXT NOT NULL,
    "use_count" INTEGER NOT NULL DEFAULT 0,
    "last_used_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "campus_app_usage_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "campus_apps_status_idx" ON "campus_apps"("status");

-- CreateIndex
CREATE INDEX "campus_apps_origin_idx" ON "campus_apps"("origin");

-- CreateIndex
CREATE INDEX "campus_apps_type_idx" ON "campus_apps"("type");

-- CreateIndex
CREATE INDEX "campus_app_usage_app_id_idx" ON "campus_app_usage"("app_id");

-- CreateIndex
CREATE INDEX "campus_app_usage_user_id_last_used_at_idx" ON "campus_app_usage"("user_id", "last_used_at");

-- CreateIndex
CREATE UNIQUE INDEX "campus_app_usage_user_id_app_id_key" ON "campus_app_usage"("user_id", "app_id");

-- AddForeignKey
ALTER TABLE "campus_apps" ADD CONSTRAINT "campus_apps_submitter_id_fkey" FOREIGN KEY ("submitter_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_apps" ADD CONSTRAINT "campus_apps_developer_id_fkey" FOREIGN KEY ("developer_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_usage" ADD CONSTRAINT "campus_app_usage_app_id_fkey" FOREIGN KEY ("app_id") REFERENCES "campus_apps"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_app_usage" ADD CONSTRAINT "campus_app_usage_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
