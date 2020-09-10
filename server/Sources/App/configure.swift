import Vapor
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// configures your application
public func configure(_ app: Application) throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    URLCache.shared.diskCapacity = 0
    URLCache.shared.memoryCapacity = 0
    URLCache.shared.removeAllCachedResponses()
    // register routes
    try routes(app)
}
