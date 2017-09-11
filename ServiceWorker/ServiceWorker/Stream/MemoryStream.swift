//
//  MemoryStreawm.swift
//  ServiceWorker
//
//  Created by alastair.coote on 11/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

class MemoryStream: WrappedStream {

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
}
