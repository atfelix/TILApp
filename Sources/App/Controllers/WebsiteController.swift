import Leaf
import Vapor

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        router.get(use: indexHandler)
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", User.parameter, use: userHandler)
        router.get("users", use: allUsersHandler)
    }

    func indexHandler(_ req: Request) throws -> Future<View> {
        return Acronym
            .query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                return try req.view().render(
                    "index",
                    IndexContent(title: "Homepage", acronyms: acronyms.isEmpty ? nil : acronyms)
                )
        }
    }

    func acronymHandler(_ req: Request) throws -> Future<View> {
        return try req
            .parameters
            .next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                return acronym
                    .user
                    .get(on: req)
                    .flatMap(to: View.self) { user in
                        return try req.view().render(
                            "acronym",
                            AcronymContent(
                                title: acronym.short,
                                acronym: acronym,
                                user: user
                            )
                        )
                }
        }
    }

    func userHandler(_ req: Request) throws -> Future<View> {
        return try req
            .parameters
            .next(User.self)
            .flatMap(to: View.self) { user in
                return try user
                    .acronyms
                    .query(on: req)
                    .all()
                    .flatMap(to: View.self) { acronyms in
                        return try req
                            .view()
                            .render(
                                "user",
                                UserContent(
                                    title: user.name,
                                    user: user,
                                    acronyms: acronyms
                                )
                        )
                }
        }
    }

    func allUsersHandler(_ req: Request) throws -> Future<View> {
        return User
            .query(on: req)
            .all()
            .flatMap(to: View.self) { users in
                return try req
                    .view()
                .render(
                    "allUsers",
                    AllUsersContent(title: "All Users", users: users)
                )
        }
    }
}

struct IndexContent: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContent: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
}

struct UserContent: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContent: Encodable {
    let title: String
    let users: [User]
}
