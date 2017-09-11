//
//  WritableStreamProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import PromiseKit

protocol WritableStreamProtocol {

    func enqueue(_ newData: Data)

    func close()

    func error(_ error: Error)

    var closed: Promise<Void> { get }
}
