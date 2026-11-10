-- CreateEnum
CREATE TYPE "PowerStatus" AS ENUM ('ON', 'OFF');

-- CreateTable
CREATE TABLE "programmes" (
    "id" BIGSERIAL NOT NULL,
    "week_label" TEXT NOT NULL,
    "title" TEXT,
    "issue_date" TEXT,
    "week_start" DATE NOT NULL,
    "week_end" DATE NOT NULL,
    "fetched_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "programmes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "power_windows" (
    "id" BIGSERIAL NOT NULL,
    "programme_id" BIGINT NOT NULL,
    "date" DATE NOT NULL,
    "subgroup" TEXT NOT NULL,
    "slot_index" INTEGER NOT NULL,
    "start_time" TIME NOT NULL,
    "end_time" TIME NOT NULL,
    "status" "PowerStatus" NOT NULL,

    CONSTRAINT "power_windows_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "locations" (
    "id" BIGSERIAL NOT NULL,
    "programme_id" BIGINT,
    "group_code" TEXT NOT NULL,
    "region" TEXT NOT NULL,
    "location" TEXT NOT NULL,
    "affected_areas" TEXT NOT NULL,

    CONSTRAINT "locations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "programmes_week_label_key" ON "programmes"("week_label");

-- CreateIndex
CREATE INDEX "power_windows_subgroup_date_idx" ON "power_windows"("subgroup", "date");

-- CreateIndex
CREATE UNIQUE INDEX "power_windows_date_subgroup_slot_index_key" ON "power_windows"("date", "subgroup", "slot_index");

-- AddForeignKey
ALTER TABLE "power_windows" ADD CONSTRAINT "power_windows_programme_id_fkey" FOREIGN KEY ("programme_id") REFERENCES "programmes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "locations" ADD CONSTRAINT "locations_programme_id_fkey" FOREIGN KEY ("programme_id") REFERENCES "programmes"("id") ON DELETE SET NULL ON UPDATE CASCADE;
