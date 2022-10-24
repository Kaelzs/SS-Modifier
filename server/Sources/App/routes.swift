import Vapor

func routes(_ app: Application) throws {
    let surgeController = SurgeController()
    try surgeController.routes(app.grouped("surge"))
}
