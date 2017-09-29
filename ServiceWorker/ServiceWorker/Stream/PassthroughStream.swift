import Foundation

public class PassthroughStream {

    public static func create() -> (input: InputStream, output: OutputStream) {
        let data = PassthroughDataHolder()
        let input = PassthroughInputStream(data: data)
        let output = PassthroughOutputStream(data: data)
        data.inputDelegate = input

        return (input, output)
    }

    fileprivate class PassthroughDataHolder {

        var data = Data(count: 0)
        weak var inputDelegate: InputStreamImplementation?

        func write(bytes: UnsafePointer<UInt8>, count: Int) -> Int {
            self.data.append(bytes, count: count)

            if let delegate = self.inputDelegate {
                delegate.emitEvent(event: .hasBytesAvailable)
            }

            // There's no situation in which we can't write all the data, so just
            // return the amount requested
            return count
        }

        func read(buffer: UnsafeMutablePointer<UInt8>, maxLength: Int) -> Int {

            let lengthToRead = min(maxLength, self.data.count)

            self.data.copyBytes(to: buffer, count: lengthToRead)
            self.data = self.data.advanced(by: lengthToRead)

            return lengthToRead
        }
    }

    fileprivate class PassthroughInputStream: InputStreamImplementation {

        let data: PassthroughDataHolder

        init(data: PassthroughDataHolder) {
            self.data = data
            super.init(data: Data(count: 0))
        }

        override func open() {
            self.streamStatus = .open
        }

        override func close() {
            self.streamStatus = .closed
        }

        override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
            return self.data.read(buffer: buffer, maxLength: len)
        }
    }

    fileprivate class PassthroughOutputStream: OutputStreamImplementation {

        let data: PassthroughDataHolder

        init(data: PassthroughDataHolder) {
            self.data = data
            super.init(toBuffer: UnsafeMutablePointer<UInt8>.allocate(capacity: 0), capacity: 0)
        }

        override func open() {
            self.streamStatus = .open
        }

        override func close() {
            self.streamStatus = .closed
        }

        override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
            return self.data.write(bytes: buffer, count: len)
        }
    }
}
