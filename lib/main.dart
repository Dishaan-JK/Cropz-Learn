import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ui/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['DM Sans'],
        await rootBundle.loadString('assets/licenses/DM-Sans-OFL.txt'));
    yield LicenseEntryWithLineBreaks(
        ['Lora'], await rootBundle.loadString('assets/licenses/Lora-OFL.txt'));
  });
  runApp(const LumiWebApp());
}
