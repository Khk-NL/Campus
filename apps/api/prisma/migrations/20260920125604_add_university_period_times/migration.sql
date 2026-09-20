-- AlterTable
ALTER TABLE "universities" ADD COLUMN     "first_period_start" TEXT NOT NULL DEFAULT '08:00',
ADD COLUMN     "period_minutes" INTEGER NOT NULL DEFAULT 45;
