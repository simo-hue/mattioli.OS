import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    if let controller = window?.rootViewController as? FlutterViewController {
      AppDelegate.registerPrivateStorageChannel(controller.binaryMessenger)
      // Must also register here: with a SceneDelegate configured, the
      // FlutterViewController is created per-scene, so AppDelegate's
      // didFinishLaunching never sees a rootViewController and the
      // `evolve/cloudkit` channel would otherwise be missing — every CloudKit
      // call from Dart would throw MissingPluginException.
      CloudKitSyncBridge.register(controller.binaryMessenger)
    }
  }
}
