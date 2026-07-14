import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.minSize = NSSize(width: 960, height: 640)
    self.setContentSize(NSSize(width: 1440, height: 900))
    self.center()
    self.title = "Evolve"
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    // iCloud sync bridge (`evolve/cloudkit`). Registered here — the single
    // window/engine creation path on macOS — so it can't miss a launch route
    // (the class of bug the iOS Scene-lifecycle registration once had).
    CloudKitSyncBridge.register(flutterViewController.engine.binaryMessenger)
    // Private-mode local-only bridge (`evolve/private_storage`): flags the
    // encrypted DB directory as backup-excluded. Same channel contract as iOS.
    PrivateStorageBridge.register(flutterViewController.engine.binaryMessenger)
    // Local-LLM bridge (`evolve/local_llm`): launches the installed Ollama app
    // so the user can start the local server without touching the terminal.
    LocalLlmBridge.register(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}
