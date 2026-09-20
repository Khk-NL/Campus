-- CreateEnum
CREATE TYPE "RecordStatus" AS ENUM ('draft', 'active', 'archived', 'disabled');

-- CreateEnum
CREATE TYPE "Role" AS ENUM ('user', 'publisher', 'developer', 'moderator', 'admin');

-- CreateEnum
CREATE TYPE "ServiceCategory" AS ENUM ('official_hub', 'academic', 'library', 'campus_card', 'venue', 'network', 'map', 'administration', 'other');

-- CreateEnum
CREATE TYPE "ServiceOrigin" AS ENUM ('official', 'student_developed', 'external', 'open_source');

-- CreateEnum
CREATE TYPE "ServiceSourceSystem" AS ENUM ('manual', 'university_adapter', 'developer_submission', 'official_directory');

-- CreateEnum
CREATE TYPE "LaunchTargetType" AS ENUM ('web', 'wechat_mini_program', 'native_app', 'campus_app');

-- CreateEnum
CREATE TYPE "WeekParity" AS ENUM ('all', 'odd', 'even');

-- CreateTable
CREATE TABLE "universities" (
    "id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "short_name" TEXT NOT NULL,
    "domain" TEXT NOT NULL,
    "logo_url" TEXT,
    "status" "RecordStatus" NOT NULL DEFAULT 'active',
    "term_weeks" INTEGER NOT NULL,
    "periods_per_day" INTEGER NOT NULL,
    "week_starts_on" INTEGER NOT NULL,
    "timezone" TEXT NOT NULL,
    "locales" TEXT[] DEFAULT ARRAY['zh-CN', 'en']::TEXT[],
    "capabilities" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "universities_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" TEXT NOT NULL,
    "university_id" TEXT NOT NULL,
    "external_user_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "avatar_url" TEXT,
    "roles" "Role"[] DEFAULT ARRAY['user']::"Role"[],
    "status" "RecordStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "campus_services" (
    "id" TEXT NOT NULL,
    "university_id" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "icon_url" TEXT,
    "category" "ServiceCategory" NOT NULL,
    "type" "LaunchTargetType" NOT NULL,
    "launch_url" TEXT,
    "launch_preferred_mode" TEXT,
    "launch_original_id" TEXT,
    "launch_path" TEXT,
    "launch_scheme" TEXT,
    "launch_fallback_url" TEXT,
    "launch_store_url" TEXT,
    "launch_app_id" TEXT,
    "launch_route" TEXT,
    "is_official" BOOLEAN NOT NULL DEFAULT false,
    "origin" "ServiceOrigin" NOT NULL,
    "source_system" "ServiceSourceSystem" NOT NULL,
    "source_id" TEXT,
    "tags" TEXT[] DEFAULT ARRAY[]::TEXT[],
    "last_verified_at" TIMESTAMP(3),
    "status" "RecordStatus" NOT NULL DEFAULT 'active',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "campus_services_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "users_university_id_idx" ON "users"("university_id");

-- CreateIndex
CREATE UNIQUE INDEX "users_university_id_external_user_id_key" ON "users"("university_id", "external_user_id");

-- CreateIndex
CREATE INDEX "campus_services_university_id_category_idx" ON "campus_services"("university_id", "category");

-- CreateIndex
CREATE INDEX "campus_services_university_id_status_idx" ON "campus_services"("university_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "campus_services_university_id_source_id_key" ON "campus_services"("university_id", "source_id");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "campus_services" ADD CONSTRAINT "campus_services_university_id_fkey" FOREIGN KEY ("university_id") REFERENCES "universities"("id") ON DELETE CASCADE ON UPDATE CASCADE;
