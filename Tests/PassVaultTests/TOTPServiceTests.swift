import Testing
import Foundation
@testable import PassVault

@Suite("TOTPService")
struct TOTPServiceTests {

    // MARK: - RFC 6238 Test Vectors

    // RFC 6238 test secret: "12345678901234567890" (ASCII)
    private var rfcSecret: Data { Data("12345678901234567890".utf8) }

    @Test("RFC 6238 SHA-1 test vectors")
    func sha1TestVectors() {
        let config = TOTPConfig(
            secret: rfcSecret,
            algorithm: .sha1,
            digits: 8,
            period: 30
        )

        // Time = 59 (counter = 1) -> 94287082
        let code1 = TOTPService.generateCode(
            config: config,
            time: Date(timeIntervalSince1970: 59)
        )
        #expect(code1 == "94287082")

        // Time = 1111111109 (counter = 37037036) -> 07081804
        let code2 = TOTPService.generateCode(
            config: config,
            time: Date(timeIntervalSince1970: 1111111109)
        )
        #expect(code2 == "07081804")

        // Time = 1234567890 (counter = 41152263) -> 89005924
        let code3 = TOTPService.generateCode(
            config: config,
            time: Date(timeIntervalSince1970: 1234567890)
        )
        #expect(code3 == "89005924")
    }

    // MARK: - Code Format

    @Test("TOTP code has correct number of digits")
    func codeDigitCount() {
        let secret = Data("testsecret123456".utf8)
        for digits in [6, 7, 8] {
            let config = TOTPConfig(secret: secret, digits: digits)
            let code = TOTPService.generateCode(config: config)
            #expect(code.count == digits)
        }
    }

    @Test("TOTP code is zero-padded")
    func codeZeroPadded() {
        let config = TOTPConfig(
            secret: rfcSecret,
            algorithm: .sha1,
            digits: 8,
            period: 30
        )
        // Time = 1111111109 produces "07081804" — leading zero
        let code = TOTPService.generateCode(
            config: config,
            time: Date(timeIntervalSince1970: 1111111109)
        )
        #expect(code.first == "0")
        #expect(code.count == 8)
    }

    @Test("TOTP code contains only digits")
    func codeOnlyDigits() {
        let config = TOTPConfig(secret: Data("anysecret1234567".utf8))
        for _ in 0..<20 {
            let code = TOTPService.generateCode(config: config)
            #expect(code.allSatisfy { $0.isNumber })
        }
    }

    // MARK: - Time-Based Behavior

    @Test("Same time produces same code")
    func sameTimeSameCode() {
        let config = TOTPConfig(secret: Data("consistent12345!".utf8))
        let time = Date(timeIntervalSince1970: 1700000000)

        let code1 = TOTPService.generateCode(config: config, time: time)
        let code2 = TOTPService.generateCode(config: config, time: time)

        #expect(code1 == code2)
    }

    @Test("Different period produces different code")
    func differentPeriodDifferentCode() {
        let secret = Data("testsecretvalue!".utf8)
        let time = Date(timeIntervalSince1970: 1700000045)

        let config30 = TOTPConfig(secret: secret, period: 30)
        let config60 = TOTPConfig(secret: secret, period: 60)

        let code30 = TOTPService.generateCode(config: config30, time: time)
        let code60 = TOTPService.generateCode(config: config60, time: time)

        // At time=45, counter=1 for period=30 but counter=0 for period=60
        #expect(code30 != code60)
    }

    // MARK: - Remaining Seconds

    @Test("Remaining seconds is in valid range")
    func remainingSecondsRange() {
        let remaining = TOTPService.remainingSeconds(period: 30)
        #expect(remaining >= 0 && remaining <= 30)
    }

    @Test("Progress is between 0 and 1")
    func progressRange() {
        let progress = TOTPService.progress(period: 30)
        #expect(progress >= 0 && progress <= 1)
    }

    // MARK: - Base32

    @Test("Base32 encode/decode round-trip")
    func base32RoundTrip() {
        let original = Data("Hello World!".utf8)
        let encoded = TOTPService.base32Encode(original)
        let decoded = TOTPService.base32Decode(encoded)

        #expect(decoded == original)
    }

    @Test("Base32 decode known values")
    func base32DecodeKnown() {
        // "JBSWY3DPEE======" = "Hello!" (RFC 4648)
        let decoded = TOTPService.base32Decode("JBSWY3DPEE")
        #expect(decoded == Data("Hello!".utf8))
    }

    @Test("Base32 decode handles padding")
    func base32DecodePadding() {
        let withPadding = TOTPService.base32Decode("MFRA====")
        let withoutPadding = TOTPService.base32Decode("MFRA")
        #expect(withPadding == withoutPadding)
    }

    @Test("Base32 decode handles lowercase")
    func base32DecodeLowercase() {
        let upper = TOTPService.base32Decode("JBSWY3DPEHPK3PXP")
        let lower = TOTPService.base32Decode("jbswy3dpehpk3pxp")
        #expect(upper == lower)
    }

    @Test("Base32 decode invalid input returns nil")
    func base32DecodeInvalid() {
        #expect(TOTPService.base32Decode("!!!invalid!!!") == nil)
    }

    @Test("Base32 encode empty data")
    func base32EncodeEmpty() {
        let encoded = TOTPService.base32Encode(Data())
        #expect(encoded.isEmpty)
    }

    // MARK: - OTPAuth URI Parsing

    @Test("Parse standard otpauth URI")
    func parseStandardURI() {
        let uri = "otpauth://totp/Example:alice@example.com?secret=JBSWY3DPEHPK3PXP&issuer=Example&algorithm=SHA1&digits=6&period=30"
        let config = TOTPService.parseOTPAuthURI(uri)

        #expect(config != nil)
        #expect(config?.issuer == "Example")
        #expect(config?.account == "Example:alice@example.com")
        #expect(config?.algorithm == .sha1)
        #expect(config?.digits == 6)
        #expect(config?.period == 30)
        #expect(config?.secret == TOTPService.base32Decode("JBSWY3DPEHPK3PXP"))
    }

    @Test("Parse URI with SHA256 algorithm")
    func parseURISHA256() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&algorithm=SHA256"
        let config = TOTPService.parseOTPAuthURI(uri)

        #expect(config?.algorithm == .sha256)
    }

    @Test("Parse URI with SHA512 algorithm")
    func parseURISHA512() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&algorithm=SHA512"
        let config = TOTPService.parseOTPAuthURI(uri)

        #expect(config?.algorithm == .sha512)
    }

    @Test("Parse URI defaults to SHA1 when algorithm missing")
    func parseURIDefaultAlgorithm() {
        let uri = "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP"
        let config = TOTPService.parseOTPAuthURI(uri)

        #expect(config?.algorithm == .sha1)
        #expect(config?.digits == 6)
        #expect(config?.period == 30)
    }

    @Test("Parse invalid URI returns nil")
    func parseInvalidURI() {
        #expect(TOTPService.parseOTPAuthURI("not a valid uri") == nil)
        #expect(TOTPService.parseOTPAuthURI("https://example.com") == nil)
        #expect(TOTPService.parseOTPAuthURI("otpauth://hotp/Test?secret=ABC") == nil)
    }

    @Test("Parse URI without secret returns nil")
    func parseURINoSecret() {
        #expect(TOTPService.parseOTPAuthURI("otpauth://totp/Test?issuer=Example") == nil)
    }
}
