import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Enable semantics for OODA observation framework
  SemanticsBinding.instance.ensureSemantics();
  runApp(const OodaShowcaseApp(variant: AppVariant.minimal));
}
