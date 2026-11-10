-- CreateTable
CREATE TABLE "status_reports" (
    "id" BIGSERIAL NOT NULL,
    "location" TEXT NOT NULL,
    "group_code" TEXT NOT NULL,
    "device_id" TEXT NOT NULL,
    "status" "PowerStatus" NOT NULL,
    "reported_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "status_reports_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "status_reports_location_group_code_status_reported_at_idx" ON "status_reports"("location", "group_code", "status", "reported_at");

-- CreateIndex
CREATE UNIQUE INDEX "status_reports_location_group_code_device_id_key" ON "status_reports"("location", "group_code", "device_id");
