/// Longest side a normal graphics card can draw, and the most pixels the
/// color converter accepts (512 MiB of RGBA, about 134 million pixels).
const exportMaxEdge = 16384;
const exportMaxPixels = 512 * 1024 * 1024 ~/ 4;
const exportSizeLimitMessage =
    '成片超过可导出的上限（最长边 16384 像素，总计约 1.34 亿像素），请缩小尺寸';

/// Export settings are separate from the dialog so the task runner can snapshot them.
class ExportOptions {
  String scope = 'selected', format = 'jpg', sizeEdge = 'long';
  bool replaceAndroidExports = false;
  String directory = '';
  int quality = 92;
  int? edgePixels;
  bool retainCaptureInfo = true, retainGps = false;
  ExportOptions copy() => ExportOptions()
    ..scope = scope
    ..format = format
    ..sizeEdge = sizeEdge
    ..replaceAndroidExports = replaceAndroidExports
    ..directory = directory
    ..quality = quality
    ..edgePixels = edgePixels
    ..retainCaptureInfo = retainCaptureInfo
    ..retainGps = retainGps;
  String? validate() {
    if (!['current', 'selected', 'edited'].contains(scope) ||
        !['jpg', 'png'].contains(format) ||
        !['long', 'short'].contains(sizeEdge)) return '导出设置无效';
    if (directory.trim().isEmpty) return '请选择输出目录';
    if (quality < 1 || quality > 100) return '画质需要在 1～100 之间';
    if (edgePixels != null && (edgePixels! < 1 || edgePixels! > exportMaxEdge))
      return '成片边长需要在 1～$exportMaxEdge 像素之间';
    return null;
  }
}

class NamingPart {
  static int _serial = 0;
  final int id = _serial++;
  final bool variable;
  String value;
  NamingPart.text(this.value) : variable = false;
  NamingPart.variable(this.value) : variable = true;
}

const namingVariables = {
  '常用': {
    'name': '原文件名',
    'date': '拍摄日期',
    'time': '拍摄时间',
    'seq': '序号',
    'seq:3': '序号补零'
  },
  '时间': {'yyyy': '年', 'MM': '月', 'dd': '日', 'HH': '时', 'mm': '分', 'ss': '秒'},
  '拍摄': {
    'camera': '相机',
    'lens': '镜头',
    'iso': 'ISO',
    'focal': '焦距',
    'fnum': '光圈',
    'shutter': '快门'
  }
};

List<NamingPart> defaultNamingTemplate() =>
    [NamingPart.variable('name'), NamingPart.text('_LumaCraft')];

enum ExportConflictChoice { keepAll, replace, skipExisting, cancel }
