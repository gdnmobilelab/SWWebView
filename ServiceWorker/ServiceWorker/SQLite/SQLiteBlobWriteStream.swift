import Foundation
import SQLite3

/// A bridge between the a Foundation OutputStream and the SQLite C API's blob functions. Important
/// to note that the SQLite streaming functions cannot change the size of a BLOB field. It must be
/// created in an INSERT or UPDATE query beforehand.
public class SQLiteBlobWriteStream: OutputStreamImplementation {

    let dbPointer: SQLiteBlobStreamPointer

    init(_ db: SQLiteConnection, table: String, column: String, row: Int64) {
        self.dbPointer = SQLiteBlobStreamPointer(db, table: table, column: column, row: row, isWrite: true)

        // Not sure why we have to call this initializer, but we'll do it with empty data
        var empty = [UInt8]()
        super.init(toBuffer: &empty, capacity: 0)
        self.streamStatus = .notOpen
    }

    public override func open() {
        do {
            try self.dbPointer.open()
            self.emitEvent(event: .openCompleted)
            self.emitEvent(event: .hasSpaceAvailable)
        } catch {
            self.streamStatus = .error
            self.streamError = error
        }
    }

    public override var hasSpaceAvailable: Bool {
        guard let state = self.dbPointer.openState else {
            // As specified in docs: https://developer.apple.com/documentation/foundation/inputstream/1409410-hasbytesavailable
            // both hasSpaceAvailable and hasBytesAvailable should return true when the actual state is unknown.
            return true
        }
        return state.currentPosition < state.blobLength
    }

    public override func close() {
        self.dbPointer.close()
        self.streamStatus = .closed
    }

    public override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        do {

            guard let state = self.dbPointer.openState else {
                throw ErrorMessage("Cannot write to a stream that is not open")
            }
            self.streamStatus = .writing

            let bytesLeft = state.blobLength - state.currentPosition

            // Same as when reading, we don't want to write more data than the blob can hold
            // so we cut it off if necessary - the streaming functions cannot change the size
            // of a blob, only UPDATEs/INSERTs can.

            let lengthToWrite = min(Int32(len), bytesLeft)

            if sqlite3_blob_write(state.pointer, buffer, lengthToWrite, state.currentPosition) != SQLITE_OK {
                guard let errMsg = sqlite3_errmsg(self.dbPointer.db.db) else {
                    throw ErrorMessage("SQLite failed, but can't get error")
                }
                let str = String(cString: errMsg)
                throw ErrorMessage(str)
            }

            // Update the position we next want to write to
            state.currentPosition += lengthToWrite

            if state.currentPosition == state.blobLength {
                self.streamStatus = .atEnd
                self.emitEvent(event: .endEncountered)
            } else {
                self.streamStatus = .open
                self.emitEvent(event: .hasSpaceAvailable)
            }

            return Int(lengthToWrite)

        } catch {
            self.throwError(error)
            return -1
        }
    }
}
