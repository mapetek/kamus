import Foundation

struct TDKAPIClient {
    private static let baseURL = "https://sozluk.gov.tr"
    
    static func searchWord(_ word: String) async throws -> [WordResult] {
        // URL encode the word properly
        let encodedWord: String
        if let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            encodedWord = encoded
        } else {
            throw APIError.invalidWord
        }
        
        let urlString = "\(baseURL)/gts?ara=\(encodedWord)"
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        // Check if data is empty
        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }
        
        // Try to decode the response
        do {
            let decoder = JSONDecoder()
            let results = try decoder.decode([WordResult].self, from: data)
            return results
        } catch let decodingError as DecodingError {
            // Print the raw data for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("API Response: \(jsonString.prefix(500))")
            }
            throw APIError.decodingError(decodingError)
        }
    }
}

// MARK: - Models

struct WordResult: Codable {
    let madde_id: String
    let kelime_no: String
    let madde: String
    let lisan: String
    let birlesikler: String
    let anlamlarListe: [Meaning]
    
    enum CodingKeys: String, CodingKey {
        case madde_id
        case kelime_no
        case madde
        case lisan
        case birlesikler
        case anlamlarListe
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        madde_id = try container.decode(String.self, forKey: .madde_id)
        kelime_no = try container.decode(String.self, forKey: .kelime_no)
        madde = try container.decode(String.self, forKey: .madde)
        lisan = try container.decodeIfPresent(String.self, forKey: .lisan) ?? ""
        birlesikler = try container.decodeIfPresent(String.self, forKey: .birlesikler) ?? ""
        anlamlarListe = try container.decode([Meaning].self, forKey: .anlamlarListe)
    }
}

struct Meaning: Codable {
    let anlam_id: String
    let anlam: String
    let anlam_sira: String
    let ozelliklerListe: [Property]?
    let orneklerListe: [Example]?
    
    enum CodingKeys: String, CodingKey {
        case anlam_id
        case anlam
        case anlam_sira
        case ozelliklerListe
        case orneklerListe
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        anlam_id = try container.decode(String.self, forKey: .anlam_id)
        anlam = try container.decode(String.self, forKey: .anlam)
        anlam_sira = try container.decode(String.self, forKey: .anlam_sira)
        ozelliklerListe = try container.decodeIfPresent([Property].self, forKey: .ozelliklerListe)
        orneklerListe = try container.decodeIfPresent([Example].self, forKey: .orneklerListe)
    }
}

struct Property: Codable {
    let ozellik_id: String
    let tam_adi: String
    let kisa_adi: String
    
    enum CodingKeys: String, CodingKey {
        case ozellik_id
        case tam_adi
        case kisa_adi
    }
}

struct Example: Codable {
    let ornek_id: String
    let ornek: String
    
    enum CodingKeys: String, CodingKey {
        case ornek_id
        case ornek
    }
}

// MARK: - Error Handling

enum APIError: LocalizedError {
    case invalidWord
    case invalidURL
    case invalidResponse
    case emptyResponse
    case serverError(Int)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidWord:
            return "Geçersiz kelime"
        case .invalidURL:
            return "Geçersiz URL"
        case .invalidResponse:
            return "Geçersiz sunucu yanıtı"
        case .emptyResponse:
            return "Sunucu boş yanıt döndürdü"
        case .serverError(let code):
            return "Sunucu hatası: \(code)"
        case .decodingError(let error):
            return "Veri işleme hatası: \(error.localizedDescription)"
        case .networkError(let error):
            return "Ağ hatası: \(error.localizedDescription)"
        }
    }
}
