#include <windows.h>
#include <wincodec.h>
#include <icm.h>
#include <shellapi.h>
#include <wrl/client.h>
#include <vector>
#include <string>
#include <stdexcept>
#include <cstdint>
using Microsoft::WRL::ComPtr;
static void Check(HRESULT hr) { if (FAILED(hr)) throw hr; }
static void Write(const void* data, size_t length) {
  const auto* p = static_cast<const unsigned char*>(data);
  while (length) { DWORD n = 0; const DWORD block = static_cast<DWORD>(length > 1048576 ? 1048576 : length);
    if (!WriteFile(GetStdHandle(STD_OUTPUT_HANDLE), p, block, &n, nullptr) || !n) throw E_FAIL;
    p += n; length -= n;
  }
}
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0; auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (!argv || argc < 2) return 2;
  const auto initialized = CoInitializeEx(nullptr, COINIT_MULTITHREADED);
  struct ComScope { bool ready; ~ComScope() { if (ready) CoUninitialize(); } } scope{SUCCEEDED(initialized)};
  try {
    Check(initialized);
    ComPtr<IWICImagingFactory> factory;
    Check(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)));
    DWORD chars = 0; GetStandardColorSpaceProfileW(nullptr, LCS_sRGB, nullptr, &chars);
    std::vector<wchar_t> profilePath(chars + 1);
    if (!GetStandardColorSpaceProfileW(nullptr, LCS_sRGB, profilePath.data(), &chars)) throw E_FAIL;
    ComPtr<IWICColorContext> destination;
    Check(factory->CreateColorContext(&destination));
    Check(destination->InitializeFromFilename(profilePath.data()));
    UINT profileSize = 0; Check(destination->GetProfileBytes(0, nullptr, &profileSize));
    std::vector<BYTE> profile(profileSize);
    Check(destination->GetProfileBytes(profileSize, profile.data(), &profileSize));
    if (std::wstring(argv[1]) == L"--profile") { Write(profile.data(), profile.size()); }
    else {
      ComPtr<IWICBitmapDecoder> decoder;
      Check(factory->CreateDecoderFromFilename(argv[1], nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &decoder));
      ComPtr<IWICBitmapFrameDecode> frame; Check(decoder->GetFrame(0, &frame));
      UINT contexts = 0; Check(frame->GetColorContexts(0, nullptr, &contexts));
      if (contexts > 32) throw E_INVALIDARG;
      std::vector<ComPtr<IWICColorContext>> owned(contexts);
      std::vector<IWICColorContext*> raw(contexts);
      for (UINT i = 0; i < contexts; i++) { Check(factory->CreateColorContext(&owned[i])); raw[i] = owned[i].Get(); }
      if (contexts) Check(frame->GetColorContexts(contexts, raw.data(), &contexts));
      ComPtr<IWICColorContext> source;
      // Prefer an embedded ICC over an EXIF-only color-space hint.
      for (auto& c : owned) { WICColorContextType type{}; Check(c->GetType(&type));
        if (type == WICColorContextProfile) { source = c; break; } }
      if (!source) for (auto& c : owned) { WICColorContextType type{}; Check(c->GetType(&type));
        if (type == WICColorContextExifColorSpace) { UINT value = 0; Check(c->GetExifColorSpace(&value));
          if (value == 1 || value == 2) { source = c; break; } } }
      if (!source) { Check(factory->CreateColorContext(&source)); Check(source->InitializeFromExifColorSpace(1)); }
      ComPtr<IWICColorTransform> color; Check(factory->CreateColorTransformer(&color));
      Check(color->Initialize(frame.Get(), source.Get(), destination.Get(), GUID_WICPixelFormat32bppRGBA));
      ComPtr<IWICBitmapSource> output = color;
      const int orientation = argc > 2 ? _wtoi(argv[2]) : 1;
      const WICBitmapTransformOptions rotations[] = {WICBitmapTransformRotate0,
        WICBitmapTransformRotate0, WICBitmapTransformFlipHorizontal, WICBitmapTransformRotate180,
        WICBitmapTransformFlipVertical, static_cast<WICBitmapTransformOptions>(WICBitmapTransformRotate90 | WICBitmapTransformFlipHorizontal),
        WICBitmapTransformRotate90, static_cast<WICBitmapTransformOptions>(WICBitmapTransformRotate270 | WICBitmapTransformFlipHorizontal), WICBitmapTransformRotate270};
      ComPtr<IWICBitmapFlipRotator> rotated;
      if (orientation > 1 && orientation <= 8) { Check(factory->CreateBitmapFlipRotator(&rotated));
        Check(rotated->Initialize(output.Get(), rotations[orientation])); output = rotated; }
      UINT width = 0, height = 0; Check(output->GetSize(&width, &height));
      const int maxEdge = argc > 3 ? _wtoi(argv[3]) : 0;
      if (maxEdge > 0 && (width > static_cast<UINT>(maxEdge) || height > static_cast<UINT>(maxEdge))) {
        const UINT limit = static_cast<UINT>(maxEdge);
        const UINT longEdge = width > height ? width : height;
        const UINT scaledWidth = static_cast<UINT>((static_cast<uint64_t>(width) * limit) / longEdge);
        const UINT scaledHeight = static_cast<UINT>((static_cast<uint64_t>(height) * limit) / longEdge);
        ComPtr<IWICBitmapScaler> scaler;
        Check(factory->CreateBitmapScaler(&scaler));
        Check(scaler->Initialize(output.Get(), scaledWidth == 0 ? 1 : scaledWidth,
            scaledHeight == 0 ? 1 : scaledHeight, WICBitmapInterpolationModeFant));
        output = scaler;
        Check(output->GetSize(&width, &height));
      }
      // The scaler can hand back BGRA. Copying those bytes as RGBA swaps red and blue.
      GUID pixelFormat{};
      Check(output->GetPixelFormat(&pixelFormat));
      if (pixelFormat != GUID_WICPixelFormat32bppRGBA) {
        ComPtr<IWICFormatConverter> converter;
        Check(factory->CreateFormatConverter(&converter));
        Check(converter->Initialize(output.Get(), GUID_WICPixelFormat32bppRGBA,
            WICBitmapDitherTypeNone, nullptr, 0.f, WICBitmapPaletteTypeCustom));
        output = converter;
      }
      const uint64_t count = static_cast<uint64_t>(width) * height * 4;
      if (!width || !height || count > 512ull * 1024 * 1024) throw E_OUTOFMEMORY;
      std::vector<BYTE> pixels(static_cast<size_t>(count));
      Check(output->CopyPixels(nullptr, width * 4, static_cast<UINT>(count), pixels.data()));
      const uint32_t header[] = {0x31434d4c, width, height, profileSize};
      Write(header, sizeof(header)); Write(profile.data(), profile.size()); Write(pixels.data(), pixels.size());
    }
    LocalFree(argv); return 0;
  } catch (HRESULT error) {
    char message[80]; const int n = wsprintfA(message, "Windows color conversion failed: 0x%08lX", static_cast<unsigned long>(error));
    DWORD written = 0; WriteFile(GetStdHandle(STD_ERROR_HANDLE), message, static_cast<DWORD>(n), &written, nullptr);
    LocalFree(argv); return 3;
  }
}
