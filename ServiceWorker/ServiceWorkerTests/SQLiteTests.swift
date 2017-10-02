import XCTest
import FMDB
import PromiseKit
@testable import ServiceWorker
import SQLite3

class SQLiteTests: XCTestCase {

    let dbPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.db")

    override func setUp() {
        super.setUp()

        do {

            if FileManager.default.fileExists(atPath: self.dbPath.path) {
                try FileManager.default.removeItem(at: self.dbPath)
            }

        } catch {
            fatalError("\(error)")
        }
    }

    override func tearDown() {
        super.tearDown()

        do {

            if FileManager.default.fileExists(atPath: self.dbPath.path) {
                try FileManager.default.removeItem(at: self.dbPath)
            }

            //            try SQLiteConnection.inConnection(self.dbPath) { db in
            //                try db.exec(sql: """
            //                    PRAGMA writable_schema = 1;
            //                    delete from sqlite_master where type in ('table', 'index', 'trigger');
            //                    PRAGMA writable_schema = 0;
            //                    VACUUM;
            //                """)
            //            }
        } catch {
            fatalError("\(error)")
        }
    }

    func testOpenDatabaseConnection() {

        var conn: SQLiteConnection?
        XCTAssertNoThrow(conn = try SQLiteConnection(dbPath))
        XCTAssert(conn!.open == true)

        XCTAssertNoThrow(try conn!.select(sql: "SELECT 1 as num") { resultSet in
            XCTAssertEqual(try resultSet.next(), true)
            XCTAssertEqual(try resultSet.int("num"), 1)
        })

        XCTAssertNoThrow(try conn!.close())
        XCTAssert(conn!.open == false)
    }

    func testOpenDatabaseConnectionPromise() {

        SQLiteConnection.inConnection(self.dbPath) { db -> Promise<Int> in

            Promise { fulfill, _ in

                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    do {
                        try db.select(sql: "SELECT 1 as num") { resultSet in
                            XCTAssertEqual(try resultSet.next(), true)
                            fulfill(try resultSet.int("num")!)
                        }
                    } catch {
                        XCTFail()
                    }
                }
            }

        }.then { intVal -> Void in
            XCTAssertEqual(intVal, 1)
        }
        .assertResolves()
    }

    func testExecQuery() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "test-table" (
                    "value" TEXT NOT NULL
                )
            """)

            try conn.close()

            let fm = FMDatabase(url: self.dbPath)
            fm.open()
            let rs = try fm.executeQuery("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='test-table';", values: nil)

            rs.next()

            XCTAssert(rs.int(forColumnIndex: 0) == 1)

            fm.close()
        }())
    }

    func testInsertQuery() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                )
            """)

            try conn.update(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["hello"])

            try conn.close()

            let fm = FMDatabase(url: self.dbPath)
            fm.open()
            let rs = try fm.executeQuery("SELECT * from testtable;", values: nil)

            XCTAssert(rs.next() == true)

            XCTAssert(rs.string(forColumn: "val")! == "hello")

            fm.close()
        }())
    }

    func testSelect() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL PRIMARY KEY,
                    "num" INT NOT NULL,
                    "blobtexttest" BLOB NOT NULL
                );
            """)

            _ = try conn.insert(sql: "INSERT INTO testtable (val, num, blobtexttest) VALUES (?,?,?);", values: ["hello", 1, "blobtest"])
            _ = try conn.insert(sql: "INSERT INTO testtable (val, num, blobtexttest) VALUES (?,?,?);", values: ["there", 2, "blobtest2"])

            let returnedValue = try conn.select(sql: "SELECT * FROM testtable", values: []) { rs -> Int in

                XCTAssert(try rs.next() == true)
                XCTAssert(try rs.string("val") == "hello")
                XCTAssert(try rs.int("num") == 1)
                XCTAssert(try rs.string("blobtexttest") == "blobtest")

                XCTAssert(try rs.next() == true)
                XCTAssert(try rs.string("val") == "there")
                XCTAssert(try rs.int("num") == 2)

                return 2
            }

            XCTAssert(returnedValue == 2)
            try conn.close()
        }())
    }

    func testSelectOfOptionalTypes() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NULL
                );

                INSERT INTO testtable (val) VALUES (NULL);
            """)

            _ = try conn.select(sql: "SELECT * FROM testtable", values: []) { rs in

                XCTAssert(try rs.next() == true)
                XCTAssert(try rs.string("val") == nil)
            }
            try conn.close()
        }())
    }

    func testInsert() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                );
            """)

            var rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["hello"])
            XCTAssert(rowId == 1)
            rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["there"])
            XCTAssert(rowId == 2)
            try conn.close()
        }())
    }

    func testBlobReadStream() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" BLOB NOT NULL
                );
            """)

            let rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["abcdefghijk".data(using: String.Encoding.utf8) as Any])

            let stream = try conn.openBlobReadStream(table: "testtable", column: "val", row: rowId)
            stream.open()

            var testData = Data(count: 3)

            _ = testData.withUnsafeMutableBytes { body in
                stream.read(body, maxLength: 3)
            }

            XCTAssert(String(data: testData, encoding: String.Encoding.utf8) == "abc")

            _ = testData.withUnsafeMutableBytes { body in
                stream.read(body, maxLength: 3)
            }

            XCTAssertEqual(String(data: testData, encoding: String.Encoding.utf8), "def")

            XCTAssert(stream.hasBytesAvailable == true)

            var restData = Data(count: 5)
            var amtRead = 0
            _ = restData.withUnsafeMutableBytes { body in
                // Should only read as much data is there, no matter what maxLength is specified
                amtRead = stream.read(body, maxLength: 11)
            }

            XCTAssert(amtRead == 5)
            XCTAssert(String(data: restData, encoding: String.Encoding.utf8) == "ghijk")
            XCTAssert(stream.hasBytesAvailable == false)

            stream.close()
            try conn.close()
        }())
    }

    func testBlobReadStreamPipe() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" BLOB NOT NULL
                );
            """)

            let rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["abcdefghijk".data(using: String.Encoding.utf8) as Any])

            let stream = try conn.openBlobReadStream(table: "testtable", column: "val", row: rowId)

            let output = OutputStream.toMemory()

            StreamPipe.pipe(from: stream, to: output, bufferSize: 1)
                .then { () -> Void in

                    let result = output.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data
                    let str = String(data: result, encoding: .utf8)

                    XCTAssertEqual(str, "abcdefghijk")
                }
                .assertResolves()

        }())
    }

    func testBlobWriteStream() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" BLOB NOT NULL
                );
            """)

            let rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES ('aaaaaaaaaaa')", values: [])

            let stream = try conn.openBlobWriteStream(table: "testtable", column: "val", row: rowId)
            stream.open()
            _ = "abc".data(using: String.Encoding.utf8)!.withUnsafeBytes { body in
                XCTAssert(stream.write(body, maxLength: 3) == 3)
            }

            _ = "def".data(using: String.Encoding.utf8)!.withUnsafeBytes { body in
                stream.write(body, maxLength: 3)
            }

            _ = "ghijk".data(using: String.Encoding.utf8)!.withUnsafeBytes { body in
                stream.write(body, maxLength: 5)
            }

            stream.close()

            try conn.select(sql: "SELECT val FROM testtable", values: []) { rs in
                XCTAssert(try rs.next() == true)
                let data = try rs.data("val")!
                let asStr = String(data: data, encoding: String.Encoding.utf8)
                XCTAssert(asStr! == "abcdefghijk")
            }
            try conn.close()
        }())
    }

    func testBlobWritePipe() {
        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" BLOB NOT NULL
                );
            """)

            let emptyRowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (zeroblob(10))", values: [])

            let toInsert = "abcdefghij".data(using: String.Encoding.utf8)!
            let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("file.temp")
            try toInsert.write(to: tempFile)

            let insertStream = InputStream(url: tempFile)!
            let writestream = try conn.openBlobWriteStream(table: "testtable", column: "val", row: emptyRowId)

            StreamPipe.pipe(from: insertStream, to: writestream, bufferSize: 1)
                .then { () -> Void in

                    NSLog("hi")
                }
                .assertResolves()

        }())
    }

    func testBlobReadWritePipe() {
        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" BLOB NOT NULL
                );
            """)

            let rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: ["abcdefghijk".data(using: String.Encoding.utf8) as Any])

            let emptyRowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (zeroblob(11))", values: [])

            let readstream = try conn.openBlobReadStream(table: "testtable", column: "val", row: rowId)

            let output = OutputStream.toMemory()

            StreamPipe.pipe(from: readstream, to: output, bufferSize: 1)
                .then {

                    let result = output.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data
                    let newInput = InputStream(data: result)
                    let writestream = try conn.openBlobWriteStream(table: "testtable", column: "val", row: emptyRowId)

                    return StreamPipe.pipe(from: newInput, to: writestream, bufferSize: 1)
                    //                    let str = String(data: result, encoding: .utf8)
                    //
                    //                    XCTAssertEqual(str, "abcdefghijk")
                }
                .then { () -> Void in
                    NSLog("yay?")
                }
                .assertResolves()

        }())
    }

    func testRowChangesNumber() {

        XCTAssertNoThrow(try {

            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                );
            """)

            XCTAssertNoThrow(_ = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: [100]))

            XCTAssertEqual(conn.lastNumberChanges, 1)

            XCTAssertNoThrow(_ = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?),(?)", values: [100, 200]))

            XCTAssertEqual(conn.lastNumberChanges, 2)
            try conn.close()
        }())
    }

    func testInsertedRowID() {

        XCTAssertNoThrow(try {

            let conn = try SQLiteConnection(self.dbPath)
            try conn.exec(sql: """
                CREATE TABLE "testtable" (
                    "val" TEXT NOT NULL
                );
            """)

            let rowId = try conn.insert(sql: "INSERT INTO testtable (val) VALUES (?)", values: [100])

            try conn.select(sql: "SELECT val FROM testtable WHERE rowid = ?", values: [rowId]) { resultSet in
                XCTAssertEqual(try resultSet.next(), true)
                XCTAssertEqual(try resultSet.int("val"), 100)
            }

            try conn.close()

        }())
    }

    func testDataTypeDetection() {

        XCTAssertNoThrow(try {
            let conn = try SQLiteConnection(self.dbPath)

            try conn.select(sql: "SELECT 'hello' as t") { resultSet in
                _ = try resultSet.next()
                XCTAssertEqual(try resultSet.getColumnType("t"), SQLiteDataType.Text)
            }

            try conn.select(sql: "SELECT 1 as t") { resultSet in
                _ = try resultSet.next()
                XCTAssertEqual(try resultSet.getColumnType("t"), SQLiteDataType.Int)
            }

            try conn.select(sql: "SELECT 1.4 as t") { resultSet in
                _ = try resultSet.next()
                XCTAssertEqual(try resultSet.getColumnType("t"), SQLiteDataType.Float)
            }

            try conn.close()

        }())
    }
}
