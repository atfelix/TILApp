import Vapor

struct CategoriesController: RouteCollection {
    func boot(router: Router) throws {
        let route = router.grouped("api", "categories")
        route.get(use: getAllHandler)
        route.get(Category.parameter, use: getHandler)
        route.get(Category.parameter, "acronyms", use: getAcronymsHandler)
        route.grouped(User.tokenAuthMiddleware(), User.guardAuthMiddleware())
            .post(Category.self, use: createHandler)
    }

    func createHandler(_ req: Request, category: Category) throws -> Future<Category> {
        return category.save(on: req)
    }

    func getAllHandler(_ req: Request) throws -> Future<[Category]> {
        return Category.query(on: req).all()
    }

    func getHandler(_ req: Request) throws -> Future<Category> {
        return try req.parameters.next(Category.self)
    }

    func getAcronymsHandler(_ req: Request) throws -> Future<[Acronym]> {
        return try req
            .parameters
            .next(Category.self)
            .flatMap(to: [Acronym].self) { category in
                try category.acronyms.query(on: req).all()
        }
    }
}
