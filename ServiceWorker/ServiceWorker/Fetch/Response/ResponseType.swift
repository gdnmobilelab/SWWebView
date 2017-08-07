//
//  ResponseType.swift
//  ServiceWorker
//
//  Created by alastair.coote on 20/07/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

public enum ResponseType: String {
    case Basic = "basic"
    case CORS = "cors"
    case Error = "error"
    case Opaque = "opaque"
    case Internal = "internal-response"
}
