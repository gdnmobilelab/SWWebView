//
//  FetchCORSRestrictions.swift
//  ServiceWorker
//
//  Created by alastair.coote on 07/09/2017.
//  Copyright © 2017 Guardian Mobile Innovation Lab. All rights reserved.
//

import Foundation

struct FetchCORSRestrictions {
    let isCrossDomain: Bool
    let allowedHeaders: [String]
}
