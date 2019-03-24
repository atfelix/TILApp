import Authentication
import Fluent
import Vapor

struct AcronymsController: RouteCollection {
    func boot(router: Router) throws {
        let route = router.grouped("api", "acronyms")
        route.get(use: getAllHandler)
        route.get(Acronym.parameter, use: getHandler)
        route.get("search", use: searchHandler)
        route.get("first", use: getFirstHandler)
        route.get("sorted" ,use: sortedHandler)
        route.get(Acronym.parameter, "user", use: getUserHandler)
        route.get(Acronym.parameter, "categories", use: getCategoriesHandler)

        let group = route.grouped(User.tokenAuthMiddleware(), User.guardAuthMiddleware())
        group.post(AcronymCreateData.self, use: createHandler)
        group.delete(Acronym.parameter, use: deleteHandler)
        group.put(Acronym.parameter, use: updateHandler)
        group.post(Acronym.parameter, "categories", Category.parameter, use: addCategoriesHandler)
        group.delete(Acronym.parameter, "categories", Category.parameter, use: removeCategoriesHandler)
    }

    func createHandler(
        _ req: Request,
        data: AcronymCreateData
    ) throws -> Future<Acronym> {
        let user = try req.requireAuthenticated(User.self)
        let acronym = try Acronym(short: data.short, long: data.long, userID: user.requireID())
        return acronym.save(on: req)
    }

    func getAllHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req).all()
    }

    func getHandler(_ req: Request) throws -> Future<Acronym> {
        return try req.parameters.next(Acronym.self)
    }

    func updateHandler(_ req: Request) throws -> Future<Acronym> {
        return try flatMap(
            to: Acronym.self,
            req.parameters.next(Acronym.self),
            req.content.decode(Acronym.self)
        ) { acronym, updatedAcronym in
            acronym.short = updatedAcronym.short
            acronym.long = updatedAcronym.long
            acronym.userID = try req.requireAuthenticated(User.self).requireID()
            return acronym.save(on: req)
        }
    }

    func deleteHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try req
            .parameters
            .next(Acronym.self)
            .delete(on: req)
            .transform(to: HTTPStatus.noContent)
    }

    func searchHandler(_ req: Request) throws -> Future<[Acronym]> {
        guard let searchTerm = req.query[String.self, at: "term"] else { throw Abort(.notFound) }

        return Acronym.query(on: req)
            .group(.or) { or in
                or.filter(\.short == searchTerm)
                or.filter(\.long == searchTerm)
            }
            .all()
    }

    func getFirstHandler(_ req: Request) throws -> Future<Acronym> {
        return Acronym.query(on: req)
            .first()
            .map(to: Acronym.self) { acronym in
                guard let acronym = acronym else { throw Abort(.notFound) }

                return acronym
        }
    }

    func sortedHandler(_ req: Request) throws -> Future<[Acronym]> {
        return Acronym.query(on: req)
            .sort(\.short, .ascending)
            .all()
    }

    func getUserHandler(_ req: Request) throws -> Future<User.Public> {
        return try req
            .parameters
            .next(Acronym.self)
            .flatMap(to: User.Public.self) { acronym in
                acronym.user.get(on: req).public
        }
    }

    func addCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(
            to: HTTPStatus.self,
            req.parameters.next(Acronym.self),
            req.parameters.next(Category.self)
        ) { acronym, category in
            acronym
                .categories
                .attach(category, on: req)
                .transform(to: .created)
        }
    }

    func getCategoriesHandler(_ req: Request) throws -> Future<[Category]> {
        return try req
            .parameters
            .next(Acronym.self)
            .flatMap(to: [Category].self) { acronym in
                try acronym.categories.query(on: req).all()
        }
    }

    func removeCategoriesHandler(_ req: Request) throws -> Future<HTTPStatus> {
        return try flatMap(
            to: HTTPStatus.self,
            req.parameters.next(Acronym.self),
            req.parameters.next(Category.self)
        ) { acronym, category in
            return acronym
                .categories
                .detach(category, on: req)
                .transform(to: .noContent)
        }
    }
}

struct AcronymCreateData: Content {
    let short: String
    let long: String
}
