import Foundation

enum Endpoint {
    case like, info
    var base: String {
        switch self {
        case .like: return "https://like-muyyng.vercel.app/like"
        case .info: return "https://infogtdevob55.vercel.app/info"
        }
    }
}

struct API {
    static func call(_ endpoint: Endpoint, uid: String) async throws -> [(String, String)] {
        var comps = URLComponents(string: endpoint.base)!
        comps.queryItems = [URLQueryItem(name: "uid", value: uid)]
        var req = URLRequest(url: comps.url!)
        req.timeoutInterval = 60
        let (data, _) = try await URLSession.shared.data(for: req)
        if let json = try? JSONSerialization.jsonObject(with: data) {
            var out: [(String, String)] = []
            flatten(json, prefix: "", into: &out)
            return out.isEmpty ? [("Kết quả", "Không có dữ liệu")] : out
        }
        return [("Phản hồi", String(data: data, encoding: .utf8) ?? "Không đọc được")]
    }

    private static func flatten(_ v: Any, prefix: String, into out: inout [(String, String)]) {
        if let d = v as? [String: Any] {
            for k in d.keys.sorted() {
                flatten(d[k]!, prefix: prefix.isEmpty ? k : "\(prefix) › \(k)", into: &out)
            }
        } else if let a = v as? [Any] {
            for (i, e) in a.enumerated() { flatten(e, prefix: "\(prefix)[\(i + 1)]", into: &out) }
        } else if !(v is NSNull) {
            out.append((prefix, "\(v)"))
        }
    }
}
