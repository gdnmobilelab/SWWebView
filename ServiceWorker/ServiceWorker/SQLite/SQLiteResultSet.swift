import Foundation
import SQLite3

public class SQLiteResultSet {

    fileprivate var statement: OpaquePointer?
    let columnNames: [String]
    var open: Bool {
        return self.statement != nil
    }

    init(statement: OpaquePointer) {
        self.statement = statement

        let numColumns = sqlite3_column_count(statement)
        var columnNames: [String] = []

        var currentColumn: Int32 = 0
        while currentColumn < numColumns {
            let name = String(cString: sqlite3_column_name(statement, currentColumn))
            columnNames.append(name)
            currentColumn += 1
        }

        self.columnNames = columnNames
    }

    fileprivate func getStatementPointer() throws -> OpaquePointer {
        guard let pointer = self.statement else {
            throw ErrorMessage("Result set is not open")
        }
        return pointer
    }

    func close() throws {
        sqlite3_finalize(try self.getStatementPointer())
        self.statement = nil
    }

    public func next() throws -> Bool {
        return sqlite3_step(try self.getStatementPointer()) == SQLITE_ROW
    }

    fileprivate func nullCheck(_ statement: OpaquePointer, _ idx: Int32) -> Bool {
        return sqlite3_column_type(statement, idx) == SQLITE_NULL
    }

    fileprivate func idxForColumnName(_ name: String) throws -> Int32 {

        guard let idx = columnNames.index(of: name) else {
            throw ErrorMessage("Column '\(name)' does not exist in result set")
        }

        return Int32(idx)
    }

    fileprivate func getColumnResult<T>(_ name: String, processor: (OpaquePointer, Int32) -> T) throws -> T? {

        let idx = try idxForColumnName(name)

        let statement = try getStatementPointer()

        if self.nullCheck(statement, idx) {
            return nil
        }

        return processor(statement, idx)
    }

    public func string(_ name: String) throws -> String? {

        guard let result = try self.getColumnResult(name, processor: sqlite3_column_text) else {
            return nil
        }

        return String(cString: result)
    }

    public func int(_ name: String) throws -> Int? {

        guard let result = try self.getColumnResult(name, processor: sqlite3_column_int) else {
            return nil
        }

        return Int(result)
    }

    public func int64(_ name: String) throws -> Int64? {

        guard let result = try self.getColumnResult(name, processor: sqlite3_column_int64) else {
            return nil
        }

        return Int64(result)
    }

    public func double(_ name: String) throws -> Double? {

        return try self.getColumnResult(name, processor: sqlite3_column_double)
    }

    public func data(_ name: String) throws -> Data? {

        let idx = try idxForColumnName(name)

        let statement = try getStatementPointer()

        if self.nullCheck(statement, idx) {
            return nil
        }

        guard let result = sqlite3_column_blob(statement, idx) else {
            throw ErrorMessage("Could not get blob for column")
        }
        let length = sqlite3_column_bytes(statement, idx)

        return Data(bytes: result, count: Int(length))
    }

    public func url(_ name: String) throws -> URL? {
        let str = try string(name)
        if let strVal = str {
            return URL(string: strVal)
        }
        return nil
    }

    public func getColumnType(_ name: String) throws -> SQLiteDataType {

        let idx = try idxForColumnName(name)
        let colType = sqlite3_column_type(try getStatementPointer(), idx)

        if colType == SQLITE_TEXT {
            return .Text
        } else if colType == SQLITE_INTEGER {
            return .Int
        } else if colType == SQLITE_BLOB {
            return .Blob
        } else if colType == SQLITE_FLOAT {
            return .Float
        } else if colType == SQLITE_NULL {
            return .Null
        } else {
            throw ErrorMessage("Did not recognise SQLite data type: \(colType)")
        }
    }
}
