import Foundation

struct IdentityData: Codable, Hashable {
    var firstName: String
    var middleName: String?
    var lastName: String
    var email: String?
    var phone: String?
    var address: Address?
    var company: String?
    var jobTitle: String?
    var dateOfBirth: Date?
    var socialSecurityNumber: String?
    var passportNumber: String?
    var licenseNumber: String?

    init(firstName: String = "", middleName: String? = nil, lastName: String = "", email: String? = nil, phone: String? = nil, address: Address? = nil, company: String? = nil, jobTitle: String? = nil, dateOfBirth: Date? = nil, socialSecurityNumber: String? = nil, passportNumber: String? = nil, licenseNumber: String? = nil) {
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.address = address
        self.company = company
        self.jobTitle = jobTitle
        self.dateOfBirth = dateOfBirth
        self.socialSecurityNumber = socialSecurityNumber
        self.passportNumber = passportNumber
        self.licenseNumber = licenseNumber
    }

    var fullName: String {
        [firstName, middleName, lastName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
