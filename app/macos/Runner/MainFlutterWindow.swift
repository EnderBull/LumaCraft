import Cocoa
import FlutterMacOS
import WebKit

class MainFlutterWindow: NSWindow {
  private var mapSheet: MapSheet?
  private var mapLookup: MapLookup?

  override func awakeFromNib() {
    let flutter = FlutterViewController()
    let windowFrame = frame
    contentViewController = flutter
    setFrame(windowFrame, display: true)
    RegisterGeneratedPlugins(registry: flutter)

    FlutterMethodChannel(name: "lumacraft/window", binaryMessenger: flutter.engine.binaryMessenger)
      .setMethodCallHandler { [weak self] call, reply in
        switch call.method {
        case "close": self?.performClose(nil)
        case "minimize": self?.miniaturize(nil)
        case "maximize": self?.zoom(nil)
        case "drag": break
        default: reply(FlutterMethodNotImplemented); return
        }
        reply(nil)
      }
    FlutterMethodChannel(name: "lumacraft/macos_map", binaryMessenger: flutter.engine.binaryMessenger)
      .setMethodCallHandler { [weak self] call, reply in
        guard let self, let args = call.arguments as? [String: Any],
              let address = args["url"] as? String, let url = URL(string: address),
              url.scheme == "http", url.host == "127.0.0.1" else {
          reply(FlutterError(code: "MAP_URL", message: "地图本机地址无效", details: nil))
          return
        }
        switch call.method {
        case "show":
          guard self.mapSheet == nil else {
            reply(FlutterError(code: "MAP_BUSY", message: "地图窗口已打开", details: nil))
            return
          }
          let sheet = MapSheet(url: url, diagnostic: args["diagnostic"] as? Bool ?? false)
          self.mapSheet = sheet
          sheet.present(on: self) { [weak self] title in
            self?.mapSheet = nil
            reply(title)
          }
        case "lookup":
          guard self.mapLookup == nil, let lng = args["lng"] as? Double,
                let lat = args["lat"] as? Double,
                lng.isFinite, lat.isFinite, abs(lng) <= 180, abs(lat) <= 90 else {
            reply(FlutterError(code: "MAP_LOOKUP", message: "地图忙或坐标无效", details: nil))
            return
          }
          let lookup = MapLookup()
          self.mapLookup = lookup
          lookup.start(url: url, lng: lng, lat: lat) { [weak self] title in
            self?.mapLookup = nil
            reply(title)
          }
        default: reply(FlutterMethodNotImplemented)
        }
      }
    super.awakeFromNib()
  }
}

private final class MapSheet: NSObject, WKNavigationDelegate {
  private let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 880, height: 640),
                                styleMask: [.titled, .resizable],
                                backing: .buffered, defer: false)
  private let browser = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
  private let status = NSTextField(labelWithString: "正在加载地图…")
  private let confirm = NSButton()
  private let url: URL
  private let diagnostic: Bool
  private var observation: NSKeyValueObservation?
  private var chosen: String?
  private weak var parent: NSWindow?

  init(url: URL, diagnostic: Bool) {
    self.url = url
    self.diagnostic = diagnostic
    super.init()
  }

  func present(on parent: NSWindow, reply: @escaping (String?) -> Void) {
    self.parent = parent
    window.title = diagnostic ? "检查地图连接" : "选择拍摄地点"
    window.minSize = NSSize(width: 460, height: 360)
    window.isReleasedWhenClosed = false
    let content = NSView()
    window.contentView = content
    let cancel = NSButton(title: diagnostic ? "关闭" : "取消", target: self,
                          action: #selector(cancelSheet))
    cancel.keyEquivalent = "\u{1b}"
    confirm.title = "使用此地点"
    confirm.target = self
    confirm.action = #selector(confirmSheet)
    confirm.isEnabled = false
    confirm.isHidden = diagnostic
    confirm.keyEquivalent = "\r"
    status.lineBreakMode = .byTruncatingTail
    status.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    let footer = NSStackView(views: [status, cancel, confirm])
    footer.orientation = .horizontal
    footer.spacing = 10
    footer.alignment = .centerY
    content.addSubview(browser)
    content.addSubview(footer)
    browser.translatesAutoresizingMaskIntoConstraints = false
    footer.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      browser.topAnchor.constraint(equalTo: content.topAnchor),
      browser.leadingAnchor.constraint(equalTo: content.leadingAnchor),
      browser.trailingAnchor.constraint(equalTo: content.trailingAnchor),
      browser.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -10),
      footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
      footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
      footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
    ])
    observation = browser.observe(\.title, options: [.new]) { [weak self] web, _ in
      guard let self, let title = web.title else { return }
      if title.hasPrefix("PICK:") && !self.diagnostic {
        let parts = title.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count >= 3, !parts[1].isEmpty || !parts[2].isEmpty else { return }
        self.chosen = title
        self.status.stringValue = parts[1].isEmpty ? String(parts[2]) : String(parts[1])
        self.confirm.isEnabled = true
      } else if title.hasPrefix("STATE:") {
        self.status.stringValue = String(title.dropFirst(6))
      } else if title.contains("DIAG_OK") {
        self.status.stringValue = "地图连接成功"
      } else if title.contains("DIAG_FAIL") {
        self.status.stringValue = "地图连接失败，请查看页面说明"
      }
    }
    browser.navigationDelegate = self
    parent.beginSheet(window) { [weak self] response in
      self?.observation = nil
      self?.browser.stopLoading()
      reply(response == .OK ? self?.chosen : nil)
    }
    browser.load(URLRequest(url: url))
  }

  @objc private func cancelSheet() { parent?.endSheet(window, returnCode: .cancel) }
  @objc private func confirmSheet() { parent?.endSheet(window, returnCode: .OK) }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
               withError error: Error) {
    status.stringValue = "地图加载失败，请检查网络或高德设置"
  }
}

private final class MapLookup {
  private let browser = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: WKWebViewConfiguration())
  private var timer: Timer?
  private var requested = false
  private var elapsed = 0
  private var evaluating = false

  func start(url: URL, lng: Double, lat: Double, reply: @escaping (String?) -> Void) {
    browser.load(URLRequest(url: url))
    timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
      guard let self, self.timer != nil else { return }
      self.elapsed += 1
      if self.elapsed > 75 {
        self.finish("GEOCODE_ERR:查询地点超时，请检查高德 Key、白名单和网络", reply)
        return
      }
      if self.evaluating { return }
      self.evaluating = true
      let script = self.requested ? "document.title" :
        "typeof window.__geocode === 'function' && (window.__geocode(\(lng), \(lat)), true)"
      self.browser.evaluateJavaScript(script) { [weak self] value, _ in
        guard let self, self.timer != nil else { return }
        self.evaluating = false
        if value as? Bool == true {
          self.requested = true
        } else if let title = value as? String,
                  title.hasPrefix("GEOCODE:") || title.hasPrefix("GEOCODE_ERR:") {
          self.finish(title, reply)
        }
      }
    }
  }

  private func finish(_ title: String, _ reply: (String?) -> Void) {
    timer?.invalidate()
    timer = nil
    browser.stopLoading()
    reply(title)
  }
}
