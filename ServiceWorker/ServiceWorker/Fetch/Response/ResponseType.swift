import Foundation

/// As outlined here: https://developer.mozilla.org/en-US/docs/Web/API/Response/type
public enum ResponseType: String {
    case Basic = "basic"
    case CORS = "cors"
    case Error = "error"
    case Opaque = "opaque"

    // default isn't mentioned on MDN, but it's what Chrome uses when you create new Response()
    case Default = "default"

    // not part of the spec, we just use this ourselves.
    case Internal = "internal-response"
}
