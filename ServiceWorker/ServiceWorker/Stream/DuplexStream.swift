//
//  Stream.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

class DuplexStream {

    fileprivate var storedData = Data()

    func enqueue(_ newData: Data) {
        self.storedData.append(newData)
    }
}
