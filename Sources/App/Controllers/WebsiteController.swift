import Leaf
import Fluent
import Vapor

struct WebsiteController: RouteCollection {
    func boot(router: Router) throws {
        router.get(use: indexHandler)
        router.get("acronyms", Acronym.parameter, use: acronymHandler)
        router.get("users", User.parameter, use: userHandler)
        router.get("users", use: allUsersHandler)
        router.get("categories", use: allCategoriesHandler)
        router.get("category", use: categoryHandler)
        router.get("acronyms", "create", use: createAcronymHandler)
        router.post(CreateAcronymData.self, at: "acronyms", "create", use: createAcronymPostHandler)
        router.get("acronyms", Acronym.parameter, "edit", use: editAcronymHandler)
        router.post("acronyms", Acronym.parameter, "edit", use: editAcronymPostHandler)
        router.post("acronyms", Acronym.parameter, "delete", use: deleteAcronymHandler)
    }

    func indexHandler(_ req: Request) throws -> Future<View> {
        return Acronym
            .query(on: req)
            .all()
            .flatMap(to: View.self) { acronyms in
                return try req.view().render(
                    "index",
                    IndexContext(title: "Homepage", acronyms: acronyms.isEmpty ? nil : acronyms)
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
                            AcronymContext(
                                title: acronym.short,
                                acronym: acronym,
                                user: user,
                                categories: try acronym.categories.query(on: req).all()
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
                                UserContext(
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
                        AllUsersContext(title: "All Users", users: users)
                )
        }
    }

    func allCategoriesHandler(_ req: Request) throws -> Future<View> {
        return try req
            .view()
            .render(
                "allCategories",
                AllCategoriesContext(
                    categories: Category
                        .query(on: req)
                        .all()
                )
        )
    }

    func categoryHandler(_ req: Request) throws -> Future<View> {
        return try req
            .parameters
            .next(Category.self)
            .flatMap(to: View.self) { category in
                let acronyms = try category.acronyms.query(on: req).all()
                let context = CategoryContext(
                    title: category.name,
                    category: category,
                    acronyms: acronyms
                )
                return try req.view().render("category", context)
        }
    }

    func createAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req
            .view()
            .render(
                "createAcronym",
                CreateAcronymContext(users: User.query(on: req).all())
        )
    }

    func createAcronymPostHandler(_ req: Request, data: CreateAcronymData) throws -> Future<Response> {
        return Acronym(short: data.short, long: data.long, userID: data.userID)
            .save(on: req)
            .flatMap(to: Response.self) { acronym in
                guard let id = acronym.id else { throw Abort(.internalServerError) }

                return (try data.categories?.compactMap { try Category.addCategory($0, to: acronym, on: req) } ?? [])
                    .flatten(on: req)
                    .transform(to: req.redirect(to: "/acronyms/\(id)"))
        }
    }

    func editAcronymHandler(_ req: Request) throws -> Future<View> {
        return try req
            .parameters
            .next(Acronym.self)
            .flatMap(to: View.self) { acronym in
                return try req
                    .view()
                    .render(
                        "createAcronym",
                        EditAcronymContext(
                            acronym: acronym,
                            users: User.query(on: req).all(),
                            categories: try acronym.categories.query(on: req).all()
                        )
                )
        }
    }

    func editAcronymPostHandler(_ req: Request) throws
        -> Future<Response> {
            return try flatMap(
                to: Response.self,
                req.parameters.next(Acronym.self),
                req.content
                    .decode(CreateAcronymData.self)) { acronym, data in
                        acronym.short = data.short
                        acronym.long = data.long
                        acronym.userID = data.userID
                        return acronym.save(on: req)
                            .flatMap(to: Response.self) { savedAcronym in
                                guard let id = savedAcronym.id else {
                                    throw Abort(.internalServerError)
                                }
                                return try acronym.categories.query(on: req).all()
                                    .flatMap(to: Response.self) { existingCategories in
                                        let existingSet = Set(existingCategories.map { $0.name })
                                        let newSet = Set(data.categories ?? [])
                                        let categoriesToAdd = newSet.subtracting(existingSet)
                                        let categoriesToRemove = existingSet.subtracting(newSet)

                                        return (try categoriesToAdd
                                                .map { try Category.addCategory($0, to: acronym, on: req) }
                                                + categoriesToRemove
                                                    .compactMap { categoryNameToRemove in
                                                        return existingCategories.first(where: { $0.name == categoryNameToRemove })
                                                    }
                                                    .map { category in
                                                        acronym.categories.detach(category, on: req)
                                            })
                                            .flatten(on: req)
                                            .transform(to: req.redirect(to: "/acronyms/\(id)"))
                                }
                        }
            }
    }

    func deleteAcronymHandler(_ req: Request) throws -> Future<Response> {
        return try req
            .parameters
            .next(Acronym.self)
            .delete(on: req)
            .transform(to: req.redirect(to: "/"))
    }
}

struct IndexContext: Encodable {
    let title: String
    let acronyms: [Acronym]?
}

struct AcronymContext: Encodable {
    let title: String
    let acronym: Acronym
    let user: User
    let categories: Future<[Category]>
}

struct UserContext: Encodable {
    let title: String
    let user: User
    let acronyms: [Acronym]
}

struct AllUsersContext: Encodable {
    let title: String
    let users: [User]
}

struct AllCategoriesContext: Encodable {
    let title = "All Categories"
    let categories: Future<[Category]>
}

struct CategoryContext: Encodable {
    let title: String
    let category: Category
    let acronyms: Future<[Acronym]>
}

struct CreateAcronymContext: Encodable {
    let title = "Create An Acronym"
    let users: Future<[User]>
}

struct EditAcronymContext: Encodable {
    let title = "Edit Acronym"
    let acronym: Acronym
    let users: Future<[User]>
    let categories: Future<[Category]>
    let editing = true
}

struct CreateAcronymData: Content {
    let userID: User.ID
    let short: String
    let long: String
    let categories: [String]?
}
