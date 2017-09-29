import Foundation
import SQLite3

public class SQLiteBlobWriteStream: OutputStream {

    let dbPointer: SQLiteBlobStreamPointer

    fileprivate weak var _delegate: StreamDelegate?

    // Get an error about abstract classes if we do not implement this. No idea why.
    public override var delegate: StreamDelegate? {
        get {
            return self._delegate
        }
        set(val) {
            self._delegate = val
        }
    }

    init(_ db: SQLiteConnection, table: String, column: String, row: Int64) {
        self.dbPointer = SQLiteBlobStreamPointer(db, table: table, column: column, row: row, isWrite: true)

        // Not sure why we have to call this initializer, but we'll do it with empty data
        var empty = [UInt8]()
        super.init(toBuffer: &empty, capacity: 0)
    }

    fileprivate var _streamStatus: Stream.Status = .notOpen

    public override var streamStatus: Stream.Status {
        return self._streamStatus
    }

    fileprivate var _streamError: Error?

    public override var streamError: Error? {
        return self._streamError
    }

    fileprivate func throwError(_ error: Error) {
        self._streamStatus = .error
        self._streamError = error
        self.delegate?.stream?(self, handle: Stream.Event.errorOccurred)
    }

    public override func open() {
        do {
            try self.dbPointer.open()
            self.delegate?.stream?(self, handle: Stream.Event.openCompleted)
        } catch {
            self._streamStatus = .error
            self._streamError = error
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
    }

    public override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
        do {

            guard let state = self.dbPointer.openState else {
                throw ErrorMessage("Cannot write to a stream that is not open")
            }

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

            return Int(lengthToWrite)

        } catch {
            self.throwError(error)
            return -1
        }
    }
}
