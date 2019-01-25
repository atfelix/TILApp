import FluentPostgreSQL
import Vapor

final class Category: Codable {
    var id: Int?
    var name: String

    init(name: String) {
        self.name = name
    }
}

extension Category: Equatable {
    static func == (lhs: Category, rhs: Category) -> Bool {
        return lhs.id == rhs.id
    }
}

extension Category: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

extension Category {
    var acronyms: Siblings<Category, Acronym, AcronymCategoryPivot> {
        return siblings()
    }

    static func addCategory(
        _ name: String,
        to acronym: Acronym,
        on req: Request
        ) throws -> Future<Void> {
        return Category
            .query(on: req)
            .filter(\.name == name)
            .first()
            .flatMap(to: Void.self) { foundCategory in
                if let existingCategory = foundCategory {
                    return acronym
                        .categories
                        .attach(existingCategory, on: req)
                        .transform(to: ())
                }
                else {
                    return Category(name: name)
                        .save(on: req)
                        .flatMap(to: Void.self) { savedCategory in
                            return acronym
                                .categories
                                .attach(savedCategory, on: req)
                                .transform(to: ())
                    }
                }
        }
    }

    static func addCategory(
        _ category: Category,
        to acronym: Acronym,
        on req: Request
        ) throws -> Future<Void> {
        return try Category.addCategory(category.name, to: acronym, on: req)
    }
}

extension Category: PostgreSQLModel {}
extension Category: Content {}
extension Category: Migration {}
extension Category: Parameter {}
