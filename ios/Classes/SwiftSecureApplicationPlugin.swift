import Flutter
import UIKit

public class SwiftSecureApplicationPlugin: NSObject, FlutterPlugin {
    private static let colorTag = 99699
    private static let blurTag = 99698
    private static let imageTag = 99697

    var secured = false
    var opacity: CGFloat = 0.2

    // Cover configuration. Defaults preserve historical behaviour
    // (translucent white + extraLight blur).
    private var coverColor: UIColor = UIColor(white: 1, alpha: 1)
    private var coverImageName: String? = nil
    private var useBlur: Bool = true
    private var useCustomCover: Bool = false

    internal let registrar: FlutterPluginRegistrar

    init(registrar: FlutterPluginRegistrar) {
        self.registrar = registrar
        super.init()
        registrar.addApplicationDelegate(self)
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "secure_application",
            binaryMessenger: registrar.messenger())
        let instance = SwiftSecureApplicationPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: Window enumeration (multi-scene safe)

    private func allVisibleWindows() -> [UIWindow] {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .filter { !$0.isHidden }
        } else {
            return UIApplication.shared.windows.filter { !$0.isHidden }
        }
    }

    // MARK: Lifecycle

    public func applicationWillResignActive(_ application: UIApplication) {
        guard secured else { return }
        addOverlays()
    }

    public func applicationDidBecomeActive(_ application: UIApplication) {
        // Caller controls removal via the `unlock` channel method;
        // do not auto-remove here so locked state survives quick switches.
    }

    // MARK: Overlay management

    private func addOverlays() {
        for window in allVisibleWindows() {
            // Already overlaid — bring to front.
            if let existingColor = window.viewWithTag(SwiftSecureApplicationPlugin.colorTag) {
                window.bringSubviewToFront(existingColor)
                if let existingBlur = window.viewWithTag(SwiftSecureApplicationPlugin.blurTag) {
                    window.bringSubviewToFront(existingBlur)
                }
                if let existingImage = window.viewWithTag(SwiftSecureApplicationPlugin.imageTag) {
                    window.bringSubviewToFront(existingImage)
                }
                continue
            }

            // Solid color or legacy translucent-white view.
            let colorView = UIView(frame: window.bounds)
            colorView.tag = SwiftSecureApplicationPlugin.colorTag
            colorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            if useCustomCover {
                colorView.backgroundColor = coverColor
            } else {
                colorView.backgroundColor = UIColor(white: 1, alpha: opacity)
            }
            window.addSubview(colorView)

            // Blur view — opt-in (default true for legacy, off when caller sets useBlur=false).
            if useBlur {
                let blurEffect = UIBlurEffect(style: .extraLight)
                let blurEffectView = UIVisualEffectView(effect: blurEffect)
                blurEffectView.frame = window.bounds
                blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                blurEffectView.tag = SwiftSecureApplicationPlugin.blurTag
                window.addSubview(blurEffectView)
                window.bringSubviewToFront(blurEffectView)
            }

            // Optional full-screen image (loaded by name from the host app's main bundle).
            if let imageName = coverImageName, let image = UIImage(named: imageName) {
                let imageView = UIImageView(image: image)
                imageView.tag = SwiftSecureApplicationPlugin.imageTag
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.translatesAutoresizingMaskIntoConstraints = false
                window.addSubview(imageView)
                NSLayoutConstraint.activate([
                    imageView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                    imageView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                    imageView.topAnchor.constraint(equalTo: window.topAnchor),
                    imageView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
                ])
                window.bringSubviewToFront(imageView)
            }

            window.bringSubviewToFront(colorView)
            window.layoutIfNeeded()
        }
    }

    private func removeOverlays() {
        for window in allVisibleWindows() {
            let colorView = window.viewWithTag(SwiftSecureApplicationPlugin.colorTag)
            let blurView = window.viewWithTag(SwiftSecureApplicationPlugin.blurTag)
            let imageView = window.viewWithTag(SwiftSecureApplicationPlugin.imageTag)
            if colorView == nil && blurView == nil && imageView == nil { continue }
            UIView.animate(withDuration: 0.5, animations: {
                colorView?.alpha = 0.0
                blurView?.alpha = 0.0
                imageView?.alpha = 0.0
            }, completion: { _ in
                colorView?.removeFromSuperview()
                blurView?.removeFromSuperview()
                imageView?.removeFromSuperview()
            })
        }
    }

    // MARK: Channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "secure":
            secured = true
            if let args = call.arguments as? [String: Any],
               let opacityNum = args["opacity"] as? NSNumber {
                self.opacity = CGFloat(truncating: opacityNum)
            }
            result(true)
        case "open":
            secured = false
            result(true)
        case "opacity":
            if let args = call.arguments as? [String: Any],
               let opacityNum = args["opacity"] as? NSNumber {
                self.opacity = CGFloat(truncating: opacityNum)
            }
            result(true)
        case "setCover":
            applyCoverArgs(call.arguments as? [String: Any])
            result(true)
        case "unlock":
            removeOverlays()
            result(true)
        case "lock":
            // Visual gate is rendered in Dart; native overlay only used during resign-active.
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func applyCoverArgs(_ args: [String: Any]?) {
        guard let args = args else { return }
        useCustomCover = true
        if let argb = args["argb"] as? NSNumber {
            coverColor = SwiftSecureApplicationPlugin.colorFromArgb(argb.uint32Value)
        }
        if let useBlurArg = args["useBlur"] as? NSNumber {
            useBlur = useBlurArg.boolValue
        }
        if let imageName = args["imageName"] as? String, !imageName.isEmpty {
            coverImageName = imageName
        } else {
            coverImageName = nil
        }
    }

    private static func colorFromArgb(_ argb: UInt32) -> UIColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}
