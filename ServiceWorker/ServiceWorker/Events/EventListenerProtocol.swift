//
//  EventListenerProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 19/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

protocol EventListener {
    func dispatch(_: Event)
    var eventName: String { get }
}
