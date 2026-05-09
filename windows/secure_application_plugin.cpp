#include "include/secure_application/secure_application_plugin.h"

// Must be included before many other Windows headers.
#include <windows.h>
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <atomic>
#include <memory>
#include <optional>
#include <sstream>
#include <string>

namespace
{
  // Custom message routed via the platform window proc to marshal hook events
  // back to the platform thread before invoking the MethodChannel.
  constexpr UINT kSecureApplicationPostMessage = WM_USER + 0x5347; // 'SG'
  constexpr WPARAM kSecureApplicationLockWParam = 1;
  constexpr WPARAM kSecureApplicationUnlockWParam = 2;

  // WDA flags (defined in Win10 SDK; kept as constants for older toolchains).
  constexpr DWORD kWdaNone = 0x00000000;
  constexpr DWORD kWdaMonitor = 0x00000001;

  // Globals owned by the (single) plugin instance.
  HHOOK flutterWindowMonitor = nullptr;
  HWINEVENTHOOK switchHook = nullptr;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel = nullptr;
  std::atomic<HWND> g_platformHwnd{nullptr};

  class SecureApplicationPlugin : public flutter::Plugin
  {
  public:
    static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

    explicit SecureApplicationPlugin(flutter::PluginRegistrarWindows *registrar);
    ~SecureApplicationPlugin() override;

    SecureApplicationPlugin(const SecureApplicationPlugin &) = delete;
    SecureApplicationPlugin &operator=(const SecureApplicationPlugin &) = delete;

  private:
    flutter::PluginRegistrarWindows *registrar_;
    int window_proc_id_ = -1;

    static LRESULT CALLBACK monitorFlutterWindowsProc(int nCode, WPARAM wParam, LPARAM lParam);
    static void CALLBACK winEventProcCallback(HWINEVENTHOOK hWinEventHook, DWORD event,
                                              HWND hwnd, LONG idObject, LONG idChild,
                                              DWORD idEventThread, DWORD dwmsEventTime);

    HWND GetRootWindow();
    std::optional<LRESULT> OnWindowMessage(HWND hwnd, UINT message,
                                           WPARAM wparam, LPARAM lparam);

    void HandleMethodCall(
        const flutter::MethodCall<flutter::EncodableValue> &method_call,
        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  };

  // static
  void SecureApplicationPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarWindows *registrar)
  {
    channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "secure_application",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_unique<SecureApplicationPlugin>(registrar);

    channel->SetMethodCallHandler(
        [plugin_pointer = plugin.get()](const auto &call, auto result) {
          plugin_pointer->HandleMethodCall(call, std::move(result));
        });

    registrar->AddPlugin(std::move(plugin));
  }

  SecureApplicationPlugin::SecureApplicationPlugin(flutter::PluginRegistrarWindows *registrar)
      : registrar_(registrar)
  {
    // Cache the top-level window so hook callbacks can PostMessage to it.
    if (auto *view = registrar_->GetView()) {
      HWND hwnd = view->GetNativeWindow();
      g_platformHwnd.store(::GetAncestor(hwnd, GA_ROOT));
    }

    // Register a window-proc delegate so we receive our custom message on the
    // platform thread.
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return OnWindowMessage(hwnd, message, wparam, lparam);
        });

    DWORD threadID = GetCurrentThreadId();
    flutterWindowMonitor =
        SetWindowsHookEx(WH_CBT, &monitorFlutterWindowsProc, NULL, threadID);

    // Listen for both desktop switch (Win+L, switch user, UAC) and foreground
    // changes so we can pair lock with unlock.
    switchHook = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_DESKTOPSWITCH,
        NULL, &winEventProcCallback, 0, 0,
        WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);
  }

  SecureApplicationPlugin::~SecureApplicationPlugin()
  {
    if (flutterWindowMonitor != nullptr) {
      UnhookWindowsHookEx(flutterWindowMonitor);
      flutterWindowMonitor = nullptr;
    }
    if (switchHook != nullptr) {
      UnhookWinEvent(switchHook);
      switchHook = nullptr;
    }
    if (window_proc_id_ != -1 && registrar_ != nullptr) {
      registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
    }
    g_platformHwnd.store(nullptr);
    channel.reset();
  }

  HWND SecureApplicationPlugin::GetRootWindow()
  {
    if (registrar_ == nullptr) return nullptr;
    flutter::FlutterView *view = registrar_->GetView();
    if (view == nullptr) return nullptr;
    HWND hwnd = view->GetNativeWindow();
    return ::GetAncestor(hwnd, GA_ROOT);
  }

  std::optional<LRESULT> SecureApplicationPlugin::OnWindowMessage(
      HWND /*hwnd*/, UINT message, WPARAM wparam, LPARAM /*lparam*/)
  {
    if (message != kSecureApplicationPostMessage || channel == nullptr) {
      return std::nullopt;
    }
    if (wparam == kSecureApplicationLockWParam) {
      channel->InvokeMethod("lock", nullptr);
    } else if (wparam == kSecureApplicationUnlockWParam) {
      channel->InvokeMethod("unlock", nullptr);
    }
    return 0;
  }

  // Hook callback runs on the hook thread; do not touch the channel here.
  void CALLBACK SecureApplicationPlugin::winEventProcCallback(
      HWINEVENTHOOK /*hWinEventHook*/, DWORD dwEvent, HWND hwnd,
      LONG /*idObject*/, LONG /*idChild*/, DWORD /*dwEventThread*/, DWORD /*dwmsEventTime*/)
  {
    HWND target = g_platformHwnd.load();
    if (target == nullptr) return;

    if (dwEvent == EVENT_SYSTEM_DESKTOPSWITCH) {
      ::PostMessage(target, kSecureApplicationPostMessage,
                    kSecureApplicationLockWParam, 0);
    } else if (dwEvent == EVENT_SYSTEM_FOREGROUND) {
      // Foreground hwnd is our window -> we just regained focus.
      if (hwnd == target) {
        ::PostMessage(target, kSecureApplicationPostMessage,
                      kSecureApplicationUnlockWParam, 0);
      }
    }
  }

  LRESULT CALLBACK SecureApplicationPlugin::monitorFlutterWindowsProc(
      int code, WPARAM wparam, LPARAM lparam)
  {
    if (code == HCBT_SYSCOMMAND) {
      HWND target = g_platformHwnd.load();
      if (target != nullptr) {
        if (SC_MINIMIZE == wparam) {
          ::PostMessage(target, kSecureApplicationPostMessage,
                        kSecureApplicationLockWParam, 0);
        } else if (SC_RESTORE == wparam) {
          ::PostMessage(target, kSecureApplicationPostMessage,
                        kSecureApplicationUnlockWParam, 0);
        }
      }
    }
    return ::CallNextHookEx(nullptr, code, wparam, lparam);
  }

  void SecureApplicationPlugin::HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result)
  {
    const std::string &method = method_call.method_name();

    if (method == "getPlatformVersion") {
      std::ostringstream version_stream;
      version_stream << "Windows ";
      if (IsWindows10OrGreater()) {
        version_stream << "10+";
      } else if (IsWindows8OrGreater()) {
        version_stream << "8";
      } else if (IsWindows7OrGreater()) {
        version_stream << "7";
      }
      result->Success(flutter::EncodableValue(version_stream.str()));
      return;
    }

    if (method == "secure") {
      HWND hwnd = GetRootWindow();
      if (hwnd == nullptr) {
        result->Error("NO_WINDOW", "No top-level window available.");
        return;
      }
      if (!::SetWindowDisplayAffinity(hwnd, kWdaMonitor)) {
        DWORD err = ::GetLastError();
        result->Error("WDA_FAILED",
                      "SetWindowDisplayAffinity(WDA_MONITOR) failed.",
                      flutter::EncodableValue(static_cast<int64_t>(err)));
        return;
      }
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (method == "open") {
      HWND hwnd = GetRootWindow();
      if (hwnd == nullptr) {
        result->Error("NO_WINDOW", "No top-level window available.");
        return;
      }
      ::SetWindowDisplayAffinity(hwnd, kWdaNone);
      result->Success(flutter::EncodableValue(true));
      return;
    }

    if (method == "lock" || method == "unlock" || method == "opacity") {
      // Visual gate handled in Dart; native side has nothing to do.
      result->Success(flutter::EncodableValue(true));
      return;
    }

    result->NotImplemented();
  }

} // namespace

void SecureApplicationPluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar)
{
  SecureApplicationPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
