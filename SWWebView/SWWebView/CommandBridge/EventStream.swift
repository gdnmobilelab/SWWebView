//
//  EventStream.swift
//  SWWebView
//
//  Created by alastair.coote on 09/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation
import WebKit

class EventStream {
    
    let host:String
    
    init(for task: WKURLSchemeTask) {
        self.host = task.request.mainDocumentURL!.host!
    }
    
    
    
}
