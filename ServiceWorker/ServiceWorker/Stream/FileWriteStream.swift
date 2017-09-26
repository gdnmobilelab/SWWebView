import Foundation
import PromiseKit

class FileWriteStream: WrappedWriteStream {

    typealias FileDownloadReturn = (filePath: URL, fileSize: Int64)

    let localURL: URL

    init?(_ url: URL) {

        self.localURL = url

        guard let stream = OutputStream(url: url, append: false) else {
            return nil
        }

        super.init(baseStream: stream)
    }

    func withDownload<T>(_ callback: @escaping (FileDownloadReturn) throws -> Promise<T>) -> Promise<T> {

        return self.closed
            .then {

                let fileAttributes = try FileManager.default.attributesOfItem(atPath: self.localURL.path)
                guard let size = fileAttributes[.size] as? Int64 else {
                    throw ErrorMessage("Could not get size of downloaded file")
                }

                return try callback(FileWriteStream.FileDownloadReturn(filePath: self.localURL, fileSize: size))
            }
    }
}
