import Authentication
import Foundation
import FluentPostgreSQL
import Vapor

final class User: Codable {
    var id: UUID?
    var name: String
    var username: String
    var password: String

    init(name: String, username: String, password: String) {
        self.name = name
        self.username = username
        self.password = password
    }
}

extension User {
    final class Public: Codable {
        var id: UUID?
        var name: String
        var username: String

        init(id: UUID?, name: String, username: String) {
            self.id = id
            self.name = name
            self.username = username
        }
    }
}

extension User {
    var acronyms: Children<User, Acronym> {
        return children(\.userID)
    }
}

extension User: PostgreSQLUUIDModel {}
extension User: Content {}
extension User: Parameter {}
extension User: PasswordAuthenticatable {}
extension User: SessionAuthenticatable {}
extension User.Public: Content {}

extension User: Migration {
    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        return Database.create(self, on: connection) { builder in
            try addProperties(to: builder)
            builder.unique(on: \.username)
        }
    }
}

extension User {
    var `public`: User.Public {
        return User.Public(id: id, name: name, username: username)
    }
}

extension User: BasicAuthenticatable {
    static let usernameKey: UsernameKey = \User.username
    static let passwordKey: PasswordKey = \User.password
}


extension Future where T: User {
    var `public`: Future<User.Public> {
        return map(to: User.Public.self) { user in
            user.public
        }
    }
}

extension User: TokenAuthenticatable {
    typealias TokenType = Token
}

struct AdminUser: Migration {
    typealias Database = PostgreSQLDatabase

    static func prepare(on connection: PostgreSQLConnection) -> Future<Void> {
        guard let password = try? BCrypt.hash("password") else { fatalError("Failed to create an Admin User") }

        let user = User(name: "Admin", username: "admin", password: password)
        return user.save(on: connection).transform(to: ())
    }

    static func revert(on connection: PostgreSQLConnection) -> Future<Void> {
        return .done(on: connection)
    }
}
