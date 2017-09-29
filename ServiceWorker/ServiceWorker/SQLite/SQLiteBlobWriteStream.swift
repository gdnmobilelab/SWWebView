import Foundation
import SQLite3

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
            let lengthToWrite = min(Int32(len), bytesLeft)

            if sqlite3_blob_write(state.pointer, buffer, lengthToWrite, state.currentPosition) != SQLITE_OK {
                guard let errMsg = sqlite3_errmsg(self.dbPointer.db.db) else {
                    throw ErrorMessage("SQLite failed, but can't get error")
                }
                let str = String(cString: errMsg)
                throw ErrorMessage(str)
            }

            state.currentPosition += lengthToWrite
            self.streamStatus = .open
            if state.currentPosition == state.blobLength {
                self.emitEvent(event: .endEncountered)
            }
            return Int(lengthToWrite)

        } catch {
            self.throwError(error)
            return -1
        }
    }
}
