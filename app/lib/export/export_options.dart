/// Export settings are separate from the dialog so the task runner can snapshot them.
class ExportOptions {
  String scope = 'selected', format = 'jpg', sizeEdge = 'long';
  String directory = '';
  int quality = 92;
  int? edgePixels;
  bool retainCaptureInfo = true, retainGps = false;
  ExportOptions copy() => ExportOptions()
    ..scope = scope
    ..format = format
    ..sizeEdge = sizeEdge
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
    if (edgePixels != null && (edgePixels! < 1 || edgePixels! > 16384))
      return '成片边长需要在 1～16384 像素之间';
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

enum ExportConflictChoice { keepAll, replace, cancel }
