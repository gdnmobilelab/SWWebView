import Foundation

/// Sometimes we want to 'clone' a stream (e.g. when cloning a FetchResponse) but we can't
/// really because once a stream starts, any clone would be out of sync. So we have this
/// PassthroughStream to help with that - if the source stream starts, it buffers the data
/// into memory, then passes on if and when read actions take place.
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
            if lengthToRead == self.data.count {
                self.data = Data(count: 0)
            } else {
                self.data = self.data.advanced(by: lengthToRead)
            }

            return lengthToRead
        }

        func close() {
            if let delegate = self.inputDelegate {
                delegate.close()
            }
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
            self.emitEvent(event: .openCompleted)
        }

        override func close() {
            self.streamStatus = .closed
            self.emitEvent(event: .endEncountered)
        }

        override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
            let amountRead = self.data.read(buffer: buffer, maxLength: len)
            
            if self.data.data.count > 0 {
                self.emitEvent(event: .hasBytesAvailable)
            } else {
                self.emitEvent(event: .endEncountered)
            }
            
            return amountRead
        }

        override var hasBytesAvailable: Bool {
            return self.data.data.count > 0
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
            self.data.close()
        }

        override var hasSpaceAvailable: Bool {
            // This is never not true
            return true
        }

        override func write(_ buffer: UnsafePointer<UInt8>, maxLength len: Int) -> Int {
            return self.data.write(bytes: buffer, count: len)
        }
    }
}
