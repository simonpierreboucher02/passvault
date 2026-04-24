import Foundation

struct CreditCardData: Codable, Hashable {
    var cardholderName: String
    var number: String
    var expirationMonth: String
    var expirationYear: String
    var cvv: String
    var brand: String?
    var billingAddress: Address?

    init(cardholderName: String = "", number: String = "", expirationMonth: String = "", expirationYear: String = "", cvv: String = "", brand: String? = nil, billingAddress: Address? = nil) {
        self.cardholderName = cardholderName
        self.number = number
        self.expirationMonth = expirationMonth
        self.expirationYear = expirationYear
        self.cvv = cvv
        self.brand = brand
        self.billingAddress = billingAddress
    }

    var maskedNumber: String {
        guard number.count >= 4 else { return number }
        let last4 = number.suffix(4)
        return "•••• •••• •••• \(last4)"
    }

    var detectedBrand: String {
        if let brand { return brand }
        guard let first = number.first else { return "Unknown" }
        switch first {
        case "4": return "Visa"
        case "5": return "Mastercard"
        case "3": return "Amex"
        case "6": return "Discover"
        default: return "Unknown"
        }
    }
}

struct Address: Codable, Hashable {
    var street1: String
    var street2: String?
    var city: String
    var state: String
    var postalCode: String
    var country: String

    init(street1: String = "", street2: String? = nil, city: String = "", state: String = "", postalCode: String = "", country: String = "") {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.country = country
    }
}
