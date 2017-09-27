
PRAGMA foreign_keys = false;

-- ----------------------------
--  Table structure for caches
-- ----------------------------
DROP TABLE IF EXISTS "caches";
CREATE TABLE "caches" (
"cache_name" TEXT NOT NULL UNIQUE,
PRIMARY KEY("cache_name")
);


PRAGMA foreign_keys = true;
