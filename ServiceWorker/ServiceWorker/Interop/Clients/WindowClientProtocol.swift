//
//  WindowClientProtocol.swift
//  ServiceWorker
//
//  Created by alastair.coote on 24/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

@objc protocol WindowClientProtocol: ClientProtocol {
    func focus(_ cb: (Error?, WindowClientProtocol?) -> Void)
    func navigate(to: URL, _ cb: (Error?, WindowClientProtocol?) -> Void)

    var focused: Bool { get }
    var visibilityState: WindowClientVisibilityState { get }
}
