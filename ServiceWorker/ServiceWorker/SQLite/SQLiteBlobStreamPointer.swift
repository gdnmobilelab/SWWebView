import Foundation
import SQLite3

class SQLiteBlobStreamPointer {

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

    let db: SQLiteConnection
    let table: String
    let column: String
    let row: Int64
    let isWriteStream: Bool
    var openState: State?

    init(_ db: SQLiteConnection, table: String, column: String, row: Int64, isWrite: Bool) {
        self.db = db
        self.table = table
        self.column = column
        self.row = row
        self.isWriteStream = isWrite
    }

    func open() throws {
        if self.openState != nil {
            Log.warn?("Tried to open a SQLiteBlobPointer that was already open")
            return
        }

        var pointer: OpaquePointer?

        let openResult = sqlite3_blob_open(self.db.db, "main", table, column, row, isWriteStream ? 1 : 0, &pointer)

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

        let blobLength = sqlite3_blob_bytes(setPointer)
        self.openState = State(pointer: setPointer, blobLength: blobLength)
    }

    func close() {
        guard let openState = self.openState else {
            Log.warn?("Tried to close a SQLiteBlobPointer that was already closed")
            return
        }
        sqlite3_blob_close(openState.pointer)
        self.openState = nil
    }
}
