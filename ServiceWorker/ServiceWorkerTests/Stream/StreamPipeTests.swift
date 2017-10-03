import XCTest
@testable import ServiceWorker
import PromiseKit

class StreamPipeTests: XCTestCase {

    func testPipingAStream() {

        let testData = "THIS IS TEST DATA".data(using: String.Encoding.utf8)!

        let inputStream = InputStream(data: testData)
        let outputStream = OutputStream.toMemory()

        StreamPipe.pipe(from: inputStream, to: outputStream, bufferSize: 1)
            .then { _ -> Void in

                let transferredData = outputStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data

                let str = String(data: transferredData, encoding: String.Encoding.utf8)

                XCTAssertEqual(str, "THIS IS TEST DATA")
            }
            .assertResolves()
    }

    func testPipingAStreamOffMainThread() {

        let testData = "THIS IS TEST DATA".data(using: String.Encoding.utf8)!

        let inputStream = InputStream(data: testData)
        let outputStream = OutputStream.toMemory()

        let (promise, fulfill, reject) = Promise<Void>.pending()

        DispatchQueue.global().async {
            StreamPipe.pipe(from: inputStream, to: outputStream, bufferSize: 1)
                .then { _ -> Void in

                    let transferredData = outputStream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data

                    let str = String(data: transferredData, encoding: String.Encoding.utf8)

                    XCTAssertEqual(str, "THIS IS TEST DATA")
                    fulfill(())
                }
                .catch { error in
                    reject(error)
                }
        }

        promise.assertResolves()
    }

    func testPipingToMultipleStreams() {

        let testData = "THIS IS TEST DATA".data(using: String.Encoding.utf8)!

        let inputStream = InputStream(data: testData)
        let outputStream = OutputStream.toMemory()
        let outputStream2 = OutputStream.toMemory()

        let streamPipe = StreamPipe(from: inputStream, bufferSize: 1)
        XCTAssertNoThrow(try streamPipe.add(stream: outputStream))
        XCTAssertNoThrow(try streamPipe.add(stream: outputStream2))

        streamPipe.pipe()
            .then { () -> Void in
                [outputStream, outputStream2].forEach { stream in
                    let transferredData = stream.property(forKey: Stream.PropertyKey.dataWrittenToMemoryStreamKey) as! Data

                    let str = String(data: transferredData, encoding: String.Encoding.utf8)

                    XCTAssertEqual(str, "THIS IS TEST DATA")
                }
            }
            .assertResolves()
    }
}
