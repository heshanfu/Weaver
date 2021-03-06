/// This file is generated by Weaver
/// DO NOT EDIT!
import Weaver
// MARK: - ImageManager
final class ImageManagerDependencyContainer: DependencyContainer {
    init(parent: DependencyContainer) {
        super.init(parent)
    }
    override func registerDependencies(in store: DependencyStore) {
        store.register(URLSession.self, scope: .container, name: "urlSession", builder: { (dependencies) in
            return self.urlSessionCustomRef(dependencies)
        })
    }
}
protocol ImageManagerDependencyResolver {
    var urlSession: URLSession { get }
    var movieAPI: APIProtocol { get }
    func urlSessionCustomRef(_ dependencies: DependencyContainer) -> URLSession
}
extension ImageManagerDependencyContainer: ImageManagerDependencyResolver {
    var urlSession: URLSession {
        return resolve(URLSession.self, name: "urlSession")
    }
    var movieAPI: APIProtocol {
        return resolve(APIProtocol.self, name: "movieAPI")
    }
}
extension ImageManager {
    static func makeImageManager(injecting parentDependencies: DependencyContainer) -> ImageManager {
        let dependencies = ImageManagerDependencyContainer(parent: parentDependencies)
        return ImageManager(injecting: dependencies)
    }
}
protocol ImageManagerDependencyInjectable {
    init(injecting dependencies: ImageManagerDependencyResolver)
}
extension ImageManager: ImageManagerDependencyInjectable {}