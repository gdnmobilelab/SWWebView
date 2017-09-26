import Foundation

public enum ResponseType: String {
    case Basic = "basic"
    case CORS = "cors"
    case Error = "error"
    case Opaque = "opaque"
    case Internal = "internal-response"
}
