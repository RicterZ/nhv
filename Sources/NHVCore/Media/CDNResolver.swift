import Foundation

public struct CDNResolver: Sendable {
    public enum MediaKind: Sendable { case image, thumbnail }
    private let configuration: CDNConfiguration

    public init(configuration: CDNConfiguration) { self.configuration = configuration }

    public func url(for path: String, kind: MediaKind) throws -> URL {
        let servers = kind == .image ? configuration.imageServers : configuration.thumbServers
        guard let server = servers.first,
              let base = URLComponents(string: server), base.scheme == "https", base.host != nil,
              base.user == nil, base.password == nil, base.query == nil, base.fragment == nil,
              base.path.isEmpty || base.path == "/",
              !path.isEmpty, !path.hasPrefix("//"), !path.contains(":"),
              !path.contains("?"), !path.contains("#"), !path.contains("\\"),
              !path.split(separator: "/").contains("..") else {
            throw APIError.invalidResponse
        }
        // Preserve server-provided paths and extensions; never reconstruct media filenames.
        let prefix = server.hasSuffix("/") ? String(server.dropLast()) : server
        let suffix = path.hasPrefix("/") ? path : "/" + path
        guard let url = URL(string: prefix + suffix), url.host == base.host else { throw APIError.invalidResponse }
        return url
    }
}
