import 'dart:io';

import '../photo_state.dart';
import 'app_settings.dart';

/// The one AppSettings instance for the running app.
///
/// Lives here rather than in `main.dart` so screens can read it without
/// importing the entry point, which would be a cycle.
final appSettings = AppSettings(
    File('${PhotoStore.defaultFile().parent.path}/app-settings.json'));
