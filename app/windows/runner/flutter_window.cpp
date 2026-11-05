#include "flutter_window.h"

#include <optional>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "lumacraft/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    const auto hwnd = GetHandle();
    const auto& method = call.method_name();
    if (method == "altPressed") {
      const auto foreground = GetForegroundWindow();
      const bool active = foreground == hwnd || IsChild(hwnd, foreground);
      const bool pressed = ((GetAsyncKeyState(VK_LMENU) |
                             GetAsyncKeyState(VK_RMENU)) & 0x8000) != 0;
      result->Success(flutter::EncodableValue(active && pressed));
      return;
    } else if (method == "minimize") {
      ShowWindow(hwnd, SW_MINIMIZE);
    } else if (method == "maximize") {
      ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    } else if (method == "close") {
      PostMessage(hwnd, WM_CLOSE, 0, 0);
    } else if (method == "drag" || method == "resize") {
      WPARAM hit = HTCAPTION;
      if (method == "resize") {
        const auto* edge = call.arguments() ? std::get_if<std::string>(call.arguments()) : nullptr;
        if (!edge || IsZoomed(hwnd)) { result->Success(); return; }
        if (*edge == "left") hit = HTLEFT;
        else if (*edge == "right") hit = HTRIGHT;
        else if (*edge == "top") hit = HTTOP;
        else if (*edge == "bottom") hit = HTBOTTOM;
        else if (*edge == "topLeft") hit = HTTOPLEFT;
        else if (*edge == "topRight") hit = HTTOPRIGHT;
        else if (*edge == "bottomLeft") hit = HTBOTTOMLEFT;
        else if (*edge == "bottomRight") hit = HTBOTTOMRIGHT;
        else { result->NotImplemented(); return; }
      }
      ReleaseCapture();
      POINT cursor{};
      GetCursorPos(&cursor);
      PostMessage(hwnd, WM_NCLBUTTONDOWN, hit, MAKELPARAM(cursor.x, cursor.y));
    } else { result->NotImplemented(); return; }
    result->Success();
  });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_SIZE:
      if (window_channel_) {
        window_channel_->InvokeMethod("maximized",
            std::make_unique<flutter::EncodableValue>(IsZoomed(hwnd) != FALSE));
      }
      break;
    case WM_NCCALCSIZE:
      if (wparam) return 0;
      break;
    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const auto monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
      MONITORINFO display{sizeof(MONITORINFO)};
      if (GetMonitorInfo(monitor, &display)) {
        info->ptMaxPosition.x = display.rcWork.left - display.rcMonitor.left;
        info->ptMaxPosition.y = display.rcWork.top - display.rcMonitor.top;
        info->ptMaxSize.x = display.rcWork.right - display.rcWork.left;
        info->ptMaxSize.y = display.rcWork.bottom - display.rcWork.top;
      }
      const auto scale = GetDpiForWindow(hwnd) / 96.0;
      info->ptMinTrackSize.x = static_cast<LONG>(1000 * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(640 * scale);
      return 0;
    }
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
