//
//  SWURLConverter.swift
//  SWWebView
//
//  Created by alastair.coote on 15/08/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

class SWURLConverter {
    
    static func toHTTP(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        components.scheme = components.host == "localhost" ? "http" : "https"
        return components.url!
    }
    
}
