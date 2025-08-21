import UIKit
import Flutter

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        // Haal de Flutter-engine uit AppDelegate
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let flutterEngine = appDelegate.flutterEngine

        // Gebruik die engine voor je viewcontroller
        let flutterViewController = FlutterViewController(engine: flutterEngine, nibName: nil, bundle: nil)

        window.rootViewController = flutterViewController
        self.window = window
        window.makeKeyAndVisible()
    }
}
