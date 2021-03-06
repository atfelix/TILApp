@testable import App
import Crypto
import FluentPostgreSQL

extension User {
    static func create(name: String = "Luke", username: String? = nil, on connection: PostgreSQLConnection) throws -> User {
        let user = User(name: name, username: username ?? UUID().uuidString, password: try BCrypt.hash("password"))
        return try user.save(on: connection).wait()
    }
}

extension Acronym {
    static func create(short: String = "TIL", long: String = "Today I Learned", user: User? = nil, on connection: PostgreSQLConnection) throws -> Acronym {
        let acronymsUser: User
        if let user = user {
            acronymsUser = user
        }
        else {
            acronymsUser = try User.create(on: connection)
        }
        let acronym = Acronym(short: short, long: long, userID: acronymsUser.id!)

        return try acronym.save(on: connection).wait()
    }
}

extension App.Category {
    static func create(name: String = "Random", on connection: PostgreSQLConnection) throws -> App.Category {
        return try Category(name: name).save(on: connection).wait()
    }
}
