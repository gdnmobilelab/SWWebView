import Foundation
import PromiseKit

protocol WritableStreamProtocol {

    func enqueue(_ newData: Data)

    func close()

    func error(_ error: Error)

    var closed: Promise<Void> { get }
}
