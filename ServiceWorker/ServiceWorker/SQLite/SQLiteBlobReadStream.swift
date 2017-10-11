import Foundation
import SQLite3

public class SQLiteBlobReadStream: InputStreamImplementation {

    let dbPointer: SQLiteBlobStreamPointer

    init(_ db: SQLiteConnection, table: String, column: String, row: Int64) {
        self.dbPointer = SQLiteBlobStreamPointer(db, table: table, column: column, row: row, isWrite: true)

        // Don't understand why, but it forces us to call a specified initializer. So we'll do it with empty data.
        let dummyData = Data(count: 0)
        super.init(data: dummyData)
        self.streamStatus = .notOpen
    }

    public override func open() {

        do {
            self.streamStatus = Stream.Status.opening
            try self.dbPointer.open()
            self.streamStatus = Stream.Status.open
            self.emitEvent(event: .openCompleted)
            self.emitEvent(event: .hasBytesAvailable)
        } catch {
            self.throwError(error)
        }
    }

    public override var hasBytesAvailable: Bool {
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

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        do {
            self.streamStatus = .reading
            guard let state = self.dbPointer.openState else {
                throw ErrorMessage("Trying to read a closed stream")
            }

            let bytesLeft = state.blobLength - state.currentPosition

            let lengthToRead = min(Int32(len), bytesLeft)

            if sqlite3_blob_read(state.pointer, buffer, lengthToRead, state.currentPosition) != SQLITE_OK {
                guard let errMsg = sqlite3_errmsg(self.dbPointer.db.db) else {
                    throw ErrorMessage("SQLite failed, but can't get error")
                }
                let str = String(cString: errMsg)
                throw ErrorMessage(str)
            }
            state.currentPosition += lengthToRead

            if state.currentPosition == state.blobLength {
                self.streamStatus = .atEnd
                self.emitEvent(event: .endEncountered)
            } else {
                self.streamStatus = .open
                self.emitEvent(event: .hasBytesAvailable)
            }
            return Int(lengthToRead)
        } catch {
            self.throwError(error)
            return -1
        }
    }
}
