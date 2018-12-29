@testable import App
import FluentPostgreSQL
import Vapor
import XCTest

final class UserTests: XCTestCase {

    let usersName = "Alice"
    let usersUsername = "alicea"
    let usersURI = "/api/users/"
    var app: Application!
    var connection: PostgreSQLConnection!

    override func setUp() {
        try! Application.reset()
        app = try! Application.testable()
        connection = try! app.newConnection(to: .psql).wait()
    }

    override func tearDown() {
        connection.close()
    }

    func testUsersCanBeRetrievedFromAPI() throws {
        let user = try User.create(name: usersName, username: usersUsername, on: connection)
        _ = try User.create(on: connection)

        let users = try app.getResponse(to: usersURI, decodeTo: [User].self)

        XCTAssertEqual(users.count, 2)
        XCTAssertEqual(users[0].name, usersName)
        XCTAssertEqual(users[0].username, usersUsername)
        XCTAssertEqual(users[0].id, user.id)
    }

    func testUserCanBeSavedWithAPI() throws {
        let user = User(name: usersName, username: usersUsername)

        let receivedUser = try app.getResponse(to: usersURI, method: .POST, headers: ["Content-type": "application/json"], data: user, decodeTo: User.self)

        XCTAssertEqual(receivedUser.name, usersName)
        XCTAssertEqual(receivedUser.username, usersUsername)
        XCTAssertNotNil(receivedUser.id)

        let users = try app.getResponse(to: usersURI, decodeTo: [User].self)

        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users[0].name, usersName)
        XCTAssertEqual(users[0].username, usersUsername)
        XCTAssertEqual(users[0].id, receivedUser.id)
    }

    func testGettingASingleUserFromTheAPI() throws {
        let user = try User.create(name: usersName, username: usersUsername, on: connection)
        let receivedUser = try app.getResponse(to: "\(usersURI)\(user.id!)", decodeTo: User.self)

        XCTAssertEqual(receivedUser.name, usersName)
        XCTAssertEqual(receivedUser.username, usersUsername)
        XCTAssertEqual(receivedUser.id, user.id)
    }

    func testGettingAUsersAcronymsFromAPI() throws {
        let user = try User.create(on: connection)
        let short = "OMG"
        let long = "Oh My God"

        let acronym = try Acronym.create(short: short, long: long, user: user, on: connection)
        _ = try Acronym.create(short: "LOL", long: "Laugh out loud", user: user, on: connection)

        let acronyms = try app.getResponse(to: "\(usersURI)\(user.id!)/acronyms", decodeTo: [Acronym].self)

        XCTAssertEqual(acronyms.count, 2)
        XCTAssertEqual(acronyms[0].id, acronym.id)
        XCTAssertEqual(acronyms[0].short, acronym.short)
        XCTAssertEqual(acronyms[0].long, acronym.long)
    }
}
