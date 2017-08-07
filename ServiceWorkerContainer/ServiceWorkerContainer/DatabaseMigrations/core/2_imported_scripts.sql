
PRAGMA foreign_keys = false;

DROP TABLE IF EXISTS "worker_imported_scripts";
CREATE TABLE "worker_imported_scripts" (
"worker_id" text NOT NULL,
"url" TEXT NOT NULL,
"headers" text NOT NULL,
"content" blob NOT NULL,
PRIMARY KEY("worker_id","url"),
CONSTRAINT "worker" FOREIGN KEY ("worker_id") REFERENCES "workers" ("worker_id") ON DELETE CASCADE
);

PRAGMA foreign_keys = true;
