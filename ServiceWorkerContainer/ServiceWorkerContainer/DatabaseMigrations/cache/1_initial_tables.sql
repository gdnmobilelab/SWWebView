
PRAGMA foreign_keys = false;

-- ----------------------------
--  Table structure for cache_requests
-- ----------------------------
DROP TABLE IF EXISTS "cache_requests";
CREATE TABLE "cache_requests" (
"request_id" TEXT NOT NULL UNIQUE,
"method" TEXT NOT NULL,
"origin" TEXT NOT NULL,
"path" TEXT NOT NULL,
"search" TEXT NOT NULL,
"headers" TEXT NOT NULL,
"body": BLOB,
PRIMARY KEY("request_id")
);


-- ----------------------------
--  Table structure for cache_responses
-- ----------------------------
DROP TABLE IF EXISTS "cache_responses";
CREATE TABLE "cache_responses" (
"response_id" TEXT NOT NULL UNIQUE,
"url" TEXT NOT NULL,
"status" INTEGER NOT NULL,
"headers" TEXT NOT NULL,
"body": BLOB,
PRIMARY KEY("response_id")
);

-- ----------------------------
--  Table structure for cache_response_vary
-- ----------------------------
DROP TABLE IF EXISTS "cache_response_vary";
CREATE TABLE "cache_response_vary" (
"response_id" TEXT NOT NULL,
"key" TEXT NOT NULL,
"value" TEXT NOT NULL,
PRIMARY KEY("response_id", "key")
);

-- ----------------------------
--  Table structure for cache_entries
-- ----------------------------
DROP TABLE IF EXISTS "cache_entries";
CREATE TABLE "cache_entries" (
"request_id" TEXT NOT NULL UNIQUE,
"response_id" TEXT NOT NULL UNIQUE,
PRIMARY KEY("request_id", "response_id")
);


PRAGMA foreign_keys = true;
