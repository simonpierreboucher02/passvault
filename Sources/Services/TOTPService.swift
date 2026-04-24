import Foundation
import CryptoKit

enum TOTPService {
    static func generateCode(config: TOTPConfig, time: Date = Date()) -> String {
        let counter = UInt64(time.timeIntervalSince1970 / config.period)
        var counterBigEndian = counter.bigEndian
        let counterData = Data(bytes: &counterBigEndian, count: 8)
        let key = SymmetricKey(data: config.secret)

        let hmacResult: Data
        switch config.algorithm {
        case .sha1:
            let hmac = HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key)
            hmacResult = Data(hmac)
        case .sha256:
            let hmac = HMAC<SHA256>.authenticationCode(for: counterData, using: key)
            hmacResult = Data(hmac)
        case .sha512:
            let hmac = HMAC<SHA512>.authenticationCode(for: counterData, using: key)
            hmacResult = Data(hmac)
        }

        let offset = Int(hmacResult[hmacResult.count - 1] & 0x0F)
        let truncated: UInt32 = hmacResult.withUnsafeBytes { ptr in
            let slice = ptr[offset..<(offset + 4)]
            var value: UInt32 = 0
            withUnsafeMutableBytes(of: &value) { dest in
                dest.copyBytes(from: slice)
            }
            return UInt32(bigEndian: value) & 0x7FFF_FFFF
        }

        let modulus = UInt32(pow(10.0, Double(config.digits)))
        let code = truncated % modulus

        return String(format: "%0\(config.digits)d", code)
    }

    static func remainingSeconds(period: TimeInterval = 30) -> Int {
        let elapsed = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        return Int(period - elapsed)
    }

    static func progress(period: TimeInterval = 30) -> Double {
        let elapsed = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
        return elapsed / period
    }

    // MARK: - OTPAuth URI Parsing

    static func parseOTPAuthURI(_ uri: String) -> TOTPConfig? {
        guard let components = URLComponents(string: uri),
              components.scheme == "otpauth",
              components.host == "totp" else { return nil }

        let params = Dictionary(
            uniqueKeysWithValues: (components.queryItems ?? [])
                .compactMap { item in
                    item.value.map { (item.name, $0) }
                }
        )

        guard let secretBase32 = params["secret"],
              let secret = base32Decode(secretBase32) else { return nil }

        let algorithm: TOTPAlgorithm
        switch params["algorithm"]?.uppercased() {
        case "SHA256": algorithm = .sha256
        case "SHA512": algorithm = .sha512
        default: algorithm = .sha1
        }

        return TOTPConfig(
            secret: secret,
            issuer: params["issuer"] ?? "",
            account: String(components.path.dropFirst()),
            algorithm: algorithm,
            digits: Int(params["digits"] ?? "6") ?? 6,
            period: TimeInterval(params["period"] ?? "30") ?? 30
        )
    }

    // MARK: - Base32

    static func base32Decode(_ input: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let cleaned = input.uppercased().replacingOccurrences(of: "=", with: "")

        var bits = 0
        var buffer: UInt64 = 0
        var output = Data()

        for char in cleaned {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            let value = UInt64(alphabet.distance(from: alphabet.startIndex, to: index))
            buffer = (buffer << 5) | value
            bits += 5

            if bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> bits) & 0xFF))
            }
        }

        return output
    }

    static func base32Encode(_ data: Data) -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var result = ""
        var buffer: UInt64 = 0
        var bits = 0

        for byte in data {
            buffer = (buffer << 8) | UInt64(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                let index = Int((buffer >> bits) & 0x1F)
                result.append(alphabet[index])
            }
        }

        if bits > 0 {
            let index = Int((buffer << (5 - bits)) & 0x1F)
            result.append(alphabet[index])
        }

        while result.count % 8 != 0 {
            result.append("=")
        }

        return result
    }
}
