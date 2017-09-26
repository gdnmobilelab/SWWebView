import Foundation
import JavaScriptCore

@objc protocol WebSQLResultSetProtocol: JSExport {
    var insertId: Int64 { get }
    var rowsAffected: Int { get }
    var rows: WebSQLResultRows { get }
}

@objc class WebSQLResultSet: NSObject, WebSQLResultSetProtocol {

    let insertId: Int64
    let rowsAffected: Int
    var rows: WebSQLResultRows

    init(fromUpdateIn connection: SQLiteConnection) throws {
        guard let lastInsertedId = connection.lastInsertRowId, let lastNumberChanges = connection.lastNumberChanges else {
            throw ErrorMessage("Could not fetch last inserted ID/last number of changes from database")
        }

        self.insertId = lastInsertedId
        self.rowsAffected = lastNumberChanges
        self.rows = WebSQLResultRows(rows: [])
    }

    init(resultSet: SQLiteResultSet, connection _: SQLiteConnection) throws {

        self.insertId = -1
        self.rowsAffected = 0
        var rows: [Any] = []

        while try resultSet.next() {

            var row = [String: Any?]()

            try resultSet.columnNames.forEach { name in

                let colType = try resultSet.getColumnType(name)

                if colType == .Text {
                    row[name] = try resultSet.string(name)
                } else if colType == .Int {
                    row[name] = try resultSet.int(name)
                } else if colType == .Float {
                    row[name] = try resultSet.double(name)
                } else if colType == .Null {
                    row[name] = NSNull()
                } else if colType == .Blob {
                    // Obviously this isn't correct, but WebSQL doesn't support
                    // binary blobs
                    row[name] = try resultSet.string(name)
                }
            }

            rows.append(row)
        }

        self.rows = WebSQLResultRows(rows: rows)
    }
}
