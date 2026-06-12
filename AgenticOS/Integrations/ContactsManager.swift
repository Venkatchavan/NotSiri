// Integrations/ContactsManager.swift – AgentOS
// Sync CNContact → SwiftData Person graph

import Foundation
import Observation
import Contacts
import SwiftData

@Observable
final class ContactsManager {

    static let shared = ContactsManager()
    private let store = CNContactStore()
    private(set) var isAuthorized = false

    private init() {}

    func requestAccess() async throws {
        let status = try await store.requestAccess(for: .contacts)
        isAuthorized = status
    }

    // MARK: - Sync Contacts → SwiftData

    func syncContactsToSwiftData(context: ModelContext) async throws {
        if !isAuthorized { try await requestAccess() }
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        let request = CNContactFetchRequest(keysToFetch: keys)

        do {
            try store.enumerateContacts(with: request) { contact, _ in
                let email = contact.emailAddresses.first?.value as String? ?? ""
                guard !email.isEmpty else { return }

                // Capture as Optional<String> to match Person.contactIdentifier: String?
                let contactID: String? = contact.identifier
                let descriptor = FetchDescriptor<Person>(
                    predicate: #Predicate { $0.contactIdentifier == contactID }
                )
                guard (try? context.fetch(descriptor))?.isEmpty == true else { return }

                let person = Person(
                    name: "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces),
                    email: email,
                    phone: contact.phoneNumbers.first?.value.stringValue,
                    organization: contact.organizationName.isEmpty ? nil : contact.organizationName,
                    contactIdentifier: contact.identifier
                )
                context.insert(person)
            }
        } catch {
            throw error
        }
    }

    // MARK: - Look up person by name fragment

    func findPerson(matching query: String, context: ModelContext) throws -> [Person] {
        try context.fetch(FetchDescriptor<Person>(
            predicate: #Predicate {
                $0.name.localizedStandardContains(query) || $0.email.localizedStandardContains(query)
            }
        ))
    }
}
