import 'package:ets_flutter/ui/palette_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('material you presets are distinct', () {
    expect(MaterialPreset.presets.length, greaterThanOrEqualTo(12));
    final seeds = MaterialPreset.presets.map((p) => p.seed.toARGB32()).toSet();
    expect(seeds.length, MaterialPreset.presets.length);
  });

  test('default seed produces a light scheme', () {
    final scheme = ColorScheme.fromSeed(seedColor: MaterialPreset.presets.first.seed);
    expect(scheme.brightness, Brightness.light);
    expect(scheme.primary, isNotNull);
  });
}
