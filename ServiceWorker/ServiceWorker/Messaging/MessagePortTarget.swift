//
//  MessagePortTarget.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

public protocol MessagePortTarget: class {
    var started: Bool { get }
    func start()
    func receiveMessage(_: ExtendableMessageEvent)
    func close()
}
