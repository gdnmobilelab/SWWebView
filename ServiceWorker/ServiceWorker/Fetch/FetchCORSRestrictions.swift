import Foundation

/// Not really much to this, just a place to store CORS stuff. Not using a tuple because
/// there will be more - Access-Control-Max-Age and so on might need be factored in.
struct FetchCORSRestrictions {
    let isCrossDomain: Bool
    let allowedHeaders: [String]
}
