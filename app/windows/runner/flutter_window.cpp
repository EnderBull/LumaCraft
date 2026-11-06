#include "flutter_window.h"

#include <optional>
#include <string>
#include <stdio.h>
#include <flutter/standard_method_codec.h>

namespace {
std::wstring ExportDataDirectory() {
  wchar_t env[32767];
  const DWORD count = GetEnvironmentVariableW(L"LUMACRAFT_DATA_DIR", env, 32767);
  if (count > 0 && count < 32767) return std::wstring(env, count);
  wchar_t exe[MAX_PATH];
  const DWORD got = GetModuleFileNameW(nullptr, exe, MAX_PATH);
  std::wstring dir = got == 0 ? L"." : std::wstring(exe, got);
  const auto slash = dir.find_last_of(L"\\/");
  if (slash != std::wstring::npos) dir.resize(slash);
  std::wstring cursor = dir;
  while (!cursor.empty()) {
    const std::wstring spec = cursor + L"\\pubspec.yaml";
    const DWORD attr = GetFileAttributesW(spec.c_str());
    if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY) == 0)
      return cursor + L"\\local";
    const auto cut = cursor.find_last_of(L"\\/");
    if (cut == std::wstring::npos) break;
    const std::wstring parent = cursor.substr(0, cut);
    if (parent.empty() || parent == cursor) break;
    cursor = parent;
  }
  return dir + L"\\local";
}

// Reads and writes the window's place on screen, so the app reopens where it
// was closed. Kept next to the other per-user files in the data directory.
struct SavedWindowState {
  int x = 0, y = 0, width = 0, height = 0;
  bool maximized = false;
  bool valid = false;
};

std::wstring WindowStatePath() {
  return ExportDataDirectory() + L"\\window-state.txt";
}

SavedWindowState LoadWindowState() {
  SavedWindowState state;
  const HANDLE file = CreateFileW(WindowStatePath().c_str(), GENERIC_READ,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return state;
  char buffer[128] = {};
  DWORD read = 0;
  const bool ok = ReadFile(file, buffer, sizeof(buffer) - 1, &read, nullptr);
  CloseHandle(file);
  if (!ok) return state;
  int x = 0, y = 0, width = 0, height = 0, maximized = 0;
  if (sscanf_s(buffer, "%d %d %d %d %d", &x, &y, &width, &height, &maximized) != 5)
    return state;
  if (width < 400 || height < 300) return state;
  // A monitor may have been unplugged since. Only reuse a place that still
  // overlaps a real screen, otherwise the window would open out of reach.
  RECT candidate{x, y, x + width, y + height};
  const HMONITOR monitor = MonitorFromRect(&candidate, MONITOR_DEFAULTTONULL);
  if (!monitor) return state;
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &info)) return state;
  RECT overlap{};
  if (!IntersectRect(&overlap, &candidate, &info.rcWork)) return state;
  if (overlap.right - overlap.left < 200 || overlap.bottom - overlap.top < 150)
    return state;
  state.x = x;
  state.y = y;
  state.width = width;
  state.height = height;
  state.maximized = maximized != 0;
  state.valid = true;
  return state;
}

void SaveWindowState(HWND window) {
  if (!window) return;
  WINDOWPLACEMENT placement{sizeof(WINDOWPLACEMENT)};
  if (!GetWindowPlacement(window, &placement)) return;
  // Always the restored size, so maximizing does not erase the normal size.
  const RECT& rect = placement.rcNormalPosition;
  const int width = rect.right - rect.left, height = rect.bottom - rect.top;
  if (width < 200 || height < 200) return;
  const bool maximized = placement.showCmd == SW_SHOWMAXIMIZED ||
                         IsZoomed(window) != FALSE;
  try {
    const std::wstring path = WindowStatePath();
    const auto cut = path.find_last_of(L"\\/");
    if (cut != std::wstring::npos)
      CreateDirectoryW(path.substr(0, cut).c_str(), nullptr);
    const HANDLE file = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
        nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return;
    char buffer[128];
    const int length = sprintf_s(buffer, "%d %d %d %d %d", rect.left, rect.top,
        width, height, maximized ? 1 : 0);
    DWORD written = 0;
    if (length > 0)
      WriteFile(file, buffer, static_cast<DWORD>(length), &written, nullptr);
    CloseHandle(file);
  } catch (...) {
  }
}

// Closing the window in the middle of an export leaves work undone, and the
// batch is reported on the next launch just like a crash. This only drops a
// marker so the message can say the window was closed instead of "the app
// stopped by itself"; the progress note must stay for the user to resume.
// Same file name as ExportRecoveryStore.dismissedFile.
void NoteVoluntaryExit() {
  try {
    const std::wstring dir = ExportDataDirectory();
    const std::wstring note = dir + L"\\export-recovery.json";
    // Nothing was being exported: leave no marker behind, or a later crash
    // would be described as a voluntary close.
    if (GetFileAttributesW(note.c_str()) == INVALID_FILE_ATTRIBUTES) return;
    CreateDirectoryW(dir.c_str(), nullptr);
    const std::wstring flag = dir + L"\\export-recovery.dismissed";
    const HANDLE file = CreateFileW(flag.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
        nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
  } catch (...) {
  }
}
}  // namespace

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Restore the last window place before the surface is created, so the
  // window does not visibly jump from the default size.
  const SavedWindowState saved = LoadWindowState();
  const HWND window = GetHandle();
  if (saved.valid && window) {
    SetWindowPos(window, nullptr, saved.x, saved.y, saved.width, saved.height,
                 SWP_NOZORDER | SWP_NOACTIVATE);
    if (saved.maximized) ShowWindow(window, SW_MAXIMIZE);
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
  // Alt+F4, the close button, and shutdown all arrive here. A hang or crash does not.
  if (message == WM_CLOSE) SaveWindowState(hwnd);
  if (message == WM_CLOSE || message == WM_QUERYENDSESSION) NoteVoluntaryExit();
  if (message == WM_QUERYENDSESSION) {
    SaveWindowState(hwnd);
    return TRUE;
  }

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
      // A borderless maximized window is still placed past the screen by the
      // thick frame. Pull the client area back to the monitor work area.
      if (wparam) {
        auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        const auto monitor =
            MonitorFromRect(params->rgrc, MONITOR_DEFAULTTONEAREST);
        MONITORINFO display{sizeof(MONITORINFO)};
        if (GetMonitorInfo(monitor, &display)) {
          const auto& window = params->rgrc[0];
          const auto& screen = display.rcMonitor;
          const bool coversScreen = window.left <= screen.left &&
                                     window.top <= screen.top &&
                                     window.right >= screen.right &&
                                     window.bottom >= screen.bottom;
          if (IsZoomed(hwnd) || coversScreen) {
            params->rgrc[0] = display.rcWork;
          }
        }
        return 0;
      }
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
