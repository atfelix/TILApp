import Crypto
import Vapor

struct UsersController: RouteCollection {
    func boot(router: Router) throws {
        let route = router.grouped("api", "users")
        route.get(use: getAllHandler)
        route.get(User.parameter, use: getHandler)
        route.get(User.parameter, "acronyms", use: getAcronymsHandler)
        route.grouped(User.basicAuthMiddleware(using: BCryptDigest()))
            .post("login", use: loginHandler)
        route.grouped(User.tokenAuthMiddleware(), User.guardAuthMiddleware())
            .post(User.self, use: createHandler)
    }

    func createHandler(_ req: Request, user: User) throws -> Future<User.Public> {
        user.password = try BCrypt.hash(user.password)
        return user.save(on: req).public
    }

    func getAllHandler(_ req: Request) throws -> Future<[User.Public]> {
        return User.query(on: req).decode(data: User.Public.self).all()
    }

    func getHandler(_ req: Request) throws -> Future<User.Public> {
        return try req.parameters.next(User.self).public
    }

    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req
            .parameters
            .next(User.self)
            .flatMap(to: [Acronym].self) { user in
                try user.acronyms.query(on: req).all()
        }
    }

    func loginHandler(_ req: Request) throws -> Future<Token> {
        let user = try req.requireAuthenticated(User.self)
        let token = try Token.generate(for: user)
        return token.save(on: req)
    }
}
