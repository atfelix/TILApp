import Authentication
import FluentPostgreSQL
import Foundation
import Vapor

final class Token: Codable {
    var id: UUID?
    var token: String
    var userID: User.ID

    init(token: String, userID: User.ID) {
        self.token = token
        self.userID = userID
    }
}

extension Token: PostgreSQLUUIDModel {}
extension Token: Content {}

extension Token: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.reference(from: \.userID, to: \User.id)
        }
    }
}

extension Token {
    static func generate(for user: User) throws -> Token {
        return try Token(
            token: try CryptoRandom().generateData(count: 16).base64EncodedString(),
            userID: user.requireID()
        )
    }
}

extension Token: Authentication.Token {
    typealias UserType = User
    static let userIDKey: UserIDKey = \Token.userID
}

extension Token: BearerAuthenticatable {
    static let tokenKey: TokenKey = \Token.token
}
