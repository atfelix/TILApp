import Vapor

/// Register your application's routes here.
public func routes(_ router: Router) throws {
    router.post("api", "acronyms") { request -> Future<Acronym> in
        return try request
            .content
            .decode(Acronym.self)
            .flatMap(to: Acronym.self) { acronym in
                return acronym.save(on: request)
        }
    }
}
