import Foundation
import SQLite3
public class SQLiteBlobStream {

    class State {
        let pointer: OpaquePointer
        let blobLength: Int32
        var currentPosition: Int32

        init(pointer: OpaquePointer, blobLength: Int32) {
            self.pointer = pointer
            self.blobLength = blobLength
            self.currentPosition = 0
        }
    }

    let table: String
    let column: String
    let row: Int64
    let db: SQLiteConnection

    public var isOpen: Bool {
        return self.openState != nil
    }

    deinit {
        if self.openState != nil {
            NSLog("deinit while open!")
        }
    }

    internal var openState: State?

    var isWriteStream: Int32 {
        return 0
    }

    init(_ db: SQLiteConnection, table: String, column: String, row: Int64) {

        self.db = db
        self.table = table
        self.column = column
        self.row = row
    }

    public func open() throws {
        if self.openState != nil {
            throw ErrorMessage("Blob stream is already open")
        }

        var pointer: OpaquePointer?

        let openResult = sqlite3_blob_open(self.db.db, "main", table, column, row, isWriteStream, &pointer)

        if openResult != SQLITE_OK {
            guard let errMsg = sqlite3_errmsg(self.db.db) else {
                throw ErrorMessage("SQLite failed, but can't get error")
            }
            let str = String(cString: errMsg)
            throw ErrorMessage("SQLite Error: \(str)")
        }

        guard let setPointer = pointer else {
            throw ErrorMessage("SQLite Blob pointer was not created successfully")
        }

        self.openState = State(pointer: setPointer, blobLength: sqlite3_blob_bytes(setPointer))
    }

    public func close() throws {

        guard let openState = self.openState else {
            throw ErrorMessage("Blob stream is not open")
        }

        sqlite3_blob_close(openState.pointer)
        self.openState = nil
    }
}
