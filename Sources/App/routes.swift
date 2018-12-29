import Fluent
import Vapor

public func routes(_ router: Router) throws {
    try router.register(collection: AcronymsController())
    try router.register(collection: UsersController())
    try router.register(collection: CategoriesController())
}
