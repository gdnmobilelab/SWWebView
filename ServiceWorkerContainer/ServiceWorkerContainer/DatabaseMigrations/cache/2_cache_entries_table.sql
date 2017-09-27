
PRAGMA foreign_keys = false;

-- ----------------------------
--  Table structure for cache_entries
-- ----------------------------
DROP TABLE IF EXISTS "cache_entries";
CREATE TABLE "cache_entries" (
"cache_name" TEXT NOT NULL,
"method" TEXT NOT NULL,
"request_url_no_query" TEXT NOT NULL,
"request_query" TEXT,
"vary_by_headers" TEXT NOT NULL,
"request_headers" TEXT NOT NULL,
"response_headers" TEXT NOT NULL,
"response_url" TEXT NOT NULL,
"response_status" INTEGER NOT NULL,
"response_body" BLOB NOT NULL,
PRIMARY KEY("cache_name", "method", "request_url_no_query", "request_query", "vary_by_headers")
);


PRAGMA foreign_keys = true;

