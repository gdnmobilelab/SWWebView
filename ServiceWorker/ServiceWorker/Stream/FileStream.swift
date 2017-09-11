//
//  FileStream.swift
//  ServiceWorker
//
//  Created by alastair.coote on 11/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

class FileStream: WrappedStream {

    typealias FileDownloadReturn = (filePath: URL, fileSize: Int64)

    let localURL: URL

    init?(_ url: URL) {

        self.localURL = url

        guard let stream = OutputStream(url: url, append: false) else {
            return nil
        }

        super.init(baseStream: stream)
    }

    func withDownload(_ callback: @escaping (FileDownloadReturn) -> AnyPromise) -> Promise<Void> {

        return self.closed
            .then {

                let fileAttributes = try FileManager.default.attributesOfItem(atPath: self.localURL.path)
                guard let size = fileAttributes[.size] as? Int64 else {
                    throw ErrorMessage("Could not get size of downloaded file")
                }

                return callback(FileStream.FileDownloadReturn(filePath: self.localURL, fileSize: size))
                    .then { _ in
                        ()
                    }
            }
    }
}
