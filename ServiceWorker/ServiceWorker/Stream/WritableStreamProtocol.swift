import Foundation
import PromiseKit

public protocol WritableStreamProtocol {

    func enqueue(_ newData: Data)

    func close()

    func error(_ error: Error)

    var closed: Promise<Void> { get }
}
