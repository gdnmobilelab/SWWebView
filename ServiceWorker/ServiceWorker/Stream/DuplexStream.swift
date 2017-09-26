import Foundation
import PromiseKit

class DuplexStream {

    fileprivate var storedData = Data()

    func enqueue(_ newData: Data) {
        self.storedData.append(newData)
    }
}
