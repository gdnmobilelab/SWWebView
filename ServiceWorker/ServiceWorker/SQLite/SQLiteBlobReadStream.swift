import Foundation
import SQLite3

public class SQLiteBlobReadStream: InputStream {

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

        // Don't understand why, but it forces us to call a specified initializer. So we'll do it with empty data.
        let dummyData = Data(count: 0)
        super.init(data: dummyData)
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
        self.delegate?.stream?(self, handle: .errorOccurred)
    }

    public override func open() {

        do {
            try self.dbPointer.open()
            self.delegate?.stream?(self, handle: .openCompleted)
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
    }

    public override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        do {
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
                self.delegate?.stream?(self, handle: .endEncountered)
            }

            return Int(lengthToRead)
        } catch {
            self.throwError(error)
            return -1
        }
    }
}
