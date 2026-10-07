import Foundation

/// Fetches currency conversion rates from Frankfurter (api.frankfurter.dev),
/// a free, open-source exchange rate API sourced from the ECB and other
/// central banks. No API key or account is required, which matters here:
/// there's no key to embed in the app or keep secret, and nothing to sign up
/// for. Rates update once daily (not real-time/intraday), which is more than
/// precise enough for tracking personal spending.
enum ExchangeRateService {

    enum ServiceError: Error {
        case invalidResponse
        case decodingFailed
    }

    private struct RateResponse: Decodable {
        let rate: Decimal
    }

    /// Returns the rate to multiply an amount in `base` by, to get its value in `quote`.
    /// e.g. fetchRate(from: "EUR", to: "USD") returning 1.09 means 1 EUR ≈ 1.09 USD.
    static func fetchRate(from base: String, to quote: String) async throws -> Decimal {
        guard base.uppercased() != quote.uppercased() else { return 1 }

        guard let url = URL(
            string: "https://api.frankfurter.dev/v2/rate/\(base.lowercased())/\(quote.lowercased())"
        ) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ServiceError.invalidResponse
        }

        do {
            let decoded = try JSONDecoder().decode(RateResponse.self, from: data)
            return decoded.rate
        } catch {
            throw ServiceError.decodingFailed
        }
    }
}
