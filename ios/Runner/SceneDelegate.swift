import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Создаем окно приложения
        self.window = UIWindow(windowScene: windowScene)

        // Получаем FlutterEngine, который инициализируется в AppDelegate
        let flutterEngine = (UIApplication.shared.delegate as! AppDelegate).flutterEngine
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)

        self.window?.rootViewController = flutterViewController
        self.window?.makeKeyAndVisible()
    }
}