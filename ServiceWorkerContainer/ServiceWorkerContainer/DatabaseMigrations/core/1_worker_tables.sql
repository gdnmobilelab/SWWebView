PRAGMA foreign_keys = false;

-- ----------------------------
--  Table structure for registrations
-- ----------------------------
DROP TABLE IF EXISTS "registrations";
CREATE TABLE "registrations" (
"scope" TEXT NOT NULL,
"active" TEXT,
"installing" TEXT,
"waiting" TEXT,
"redundant" TEXT,
PRIMARY KEY("scope"),
CONSTRAINT "active_worker" FOREIGN KEY ("active") REFERENCES "workers" ("worker_id") ON DELETE SET NULL,
CONSTRAINT "installing_worker" FOREIGN KEY ("installing") REFERENCES "workers" ("worker_id") ON DELETE SET NULL,
CONSTRAINT "waiting_worker" FOREIGN KEY ("waiting") REFERENCES "workers" ("worker_id") ON DELETE SET NULL,
CONSTRAINT "redundant_worker" FOREIGN KEY ("redundant") REFERENCES "workers" ("worker_id") ON DELETE SET NULL
);

-- ----------------------------
--  Table structure for workers
-- ----------------------------
DROP TABLE IF EXISTS "workers";
CREATE TABLE "workers" (
"worker_id" text(36,0) NOT NULL,
"url" text NOT NULL,
"scope" text NOT NULL,
"headers" text NOT NULL,
"content" blob NOT NULL,
"install_state" integer NOT NULL,
PRIMARY KEY("worker_id")
);

PRAGMA foreign_keys = true;

