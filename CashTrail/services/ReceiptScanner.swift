import Vision
import UIKit
import Foundation

struct ReceiptOCRResult {
    var merchant: String
    var amount: Decimal?
    var date: Date?
    var rawText: String
}

/// Runs Vision text recognition on a receipt image and applies simple
/// heuristics to guess the merchant name, total amount, and date.
///
/// These heuristics won't be perfect for every receipt layout — that's why
/// the app always shows a review screen before saving, rather than trusting
/// OCR blindly.
enum ReceiptScanner {

    enum ScanError: Error {
        case invalidImage
        case noText
    }

    static func recognizeText(
        in image: UIImage,
        completion: @escaping (Result<ReceiptOCRResult, Error>) -> Void
    ) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ScanError.invalidImage))
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.failure(ScanError.noText))
                return
            }

            let lines: [(text: String, box: CGRect)] = observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return (candidate.string, obs.boundingBox)
            }

            let rawText = lines.map(\.text).joined(separator: "\n")
            let amount = extractAmount(from: lines.map(\.text))
            let merchant = extractMerchant(from: lines)
            let date = extractDate(from: lines.map(\.text))

            completion(.success(ReceiptOCRResult(merchant: merchant, amount: amount, date: date, rawText: rawText)))
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Amount extraction

    private static func extractAmount(from lines: [String]) -> Decimal? {
        let totalKeywords = ["total", "amount due", "grand total", "balance due"]
        let lowerPriorityKeywords = ["subtotal", "sub total", "tax", "change", "cash", "tip"]

        // Matches numbers like 12.34, 1,234.56, 1.234,56
        let currencyRegex = try! NSRegularExpression(pattern: #"(\d{1,3}(?:[.,]\d{3})*[.,]\d{2})"#)

        var candidates: [(value: Decimal, priority: Int)] = []

        for line in lines {
            let lower = line.lowercased()
            let matches = currencyRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))

            for match in matches {
                guard let range = Range(match.range(at: 1), in: line),
                      let decimal = parseDecimal(String(line[range])) else { continue }

                var priority = 2 // bare number, no label
                if lower.contains("subtotal") {
                    priority = 1
                } else if totalKeywords.contains(where: { lower.contains($0) }) {
                    priority = 3
                } else if lowerPriorityKeywords.contains(where: { lower.contains($0) }) {
                    priority = 1
                }
                candidates.append((decimal, priority))
            }
        }

        guard !candidates.isEmpty else { return nil }

        let maxPriority = candidates.map(\.priority).max()!
        // Among the highest-priority matches, the total is usually the largest value
        // (line items are smaller than the sum). Falls back gracefully if there's only one.
        return candidates.filter { $0.priority == maxPriority }.map(\.value).max()
    }

    private static func parseDecimal(_ string: String) -> Decimal? {
        var normalized = string
        if normalized.contains(","), normalized.contains(".") {
            if normalized.lastIndex(of: ",")! > normalized.lastIndex(of: ".")! {
                // European style: 1.234,56
                normalized = normalized.replacingOccurrences(of: ".", with: "")
                normalized = normalized.replacingOccurrences(of: ",", with: ".")
            } else {
                // US style: 1,234.56
                normalized = normalized.replacingOccurrences(of: ",", with: "")
            }
        } else if normalized.contains(",") {
            let parts = normalized.split(separator: ",")
            if parts.last?.count == 2 {
                normalized = normalized.replacingOccurrences(of: ",", with: ".")
            } else {
                normalized = normalized.replacingOccurrences(of: ",", with: "")
            }
        }
        return Decimal(string: normalized)
    }

    // MARK: - Merchant extraction

    private static func extractMerchant(from lines: [(text: String, box: CGRect)]) -> String {
        // Vision's bounding box origin is bottom-left, so a higher minY means higher on the page.
        let topLines = lines.sorted { $0.box.minY > $1.box.minY }.prefix(6)

        let skipSubstrings = ["www.", "http", "tel:", "phone", "receipt", "invoice"]
        let phoneRegex = try! NSRegularExpression(pattern: #"\d{3}[-.\s]?\d{3,4}[-.\s]?\d{4}"#)
        let mostlyDigitsRegex = try! NSRegularExpression(pattern: #"^\d[\d\s\-.,/]*$"#)

        for line in topLines {
            let trimmed = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 1 else { continue }
            let lower = trimmed.lowercased()

            if skipSubstrings.contains(where: { lower.contains($0) }) { continue }
            if phoneRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil { continue }
            if mostlyDigitsRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil { continue }

            return trimmed
        }

        return topLines.first?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Merchant"
    }

    // MARK: - Date extraction

    private static func extractDate(from lines: [String]) -> Date? {
        let patterns = [
            "MM/dd/yyyy", "M/d/yyyy", "MM/dd/yy", "M/d/yy",
            "dd/MM/yyyy", "dd.MM.yyyy", "yyyy-MM-dd",
            "MMM d, yyyy", "MMMM d, yyyy", "d MMM yyyy"
        ]
        let dateRegex = try! NSRegularExpression(pattern: #"(\d{1,4}[./-]\d{1,2}[./-]\d{1,4})"#)

        for line in lines {
            let matches = dateRegex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                guard let range = Range(match.range(at: 1), in: line) else { continue }
                let dateString = String(line[range])
                for pattern in patterns {
                    let formatter = DateFormatter()
                    formatter.dateFormat = pattern
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
            }
        }
        return nil
    }
}
