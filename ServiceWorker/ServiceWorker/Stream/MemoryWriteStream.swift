import Foundation
import PromiseKit

class MemoryWriteStream: WrappedWriteStream {

    init() {
        super.init(baseStream: OutputStream.toMemory())
    }

    public var allData: Promise<Data> {
        return self.closed.then { () -> Data in
            guard let data = self.baseStream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                let error = ErrorMessage("Could not get complete data from stream")
                throw error
            }
            return data
        }
    }

    override func close() {
        super.close()
        // For some reason memory stream isn't emitting event?
        self.closedPromise.fulfill(())
    }
}
