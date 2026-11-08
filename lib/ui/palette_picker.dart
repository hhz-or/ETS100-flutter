import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';

import 'glass.dart';


/// Android 12+ / Material You 的“基础颜色”预设。
@immutable
class MaterialPreset {
  const MaterialPreset(this.name, this.seed);
  final String name;
  final Color seed;

  static const presets = <MaterialPreset>[
    MaterialPreset('默认绿', Color(0xFF4CAF50)),
    MaterialPreset('粉红色', Color(0xFFF06292)),
    MaterialPreset('红色', Color(0xFFE53935)),
    MaterialPreset('橙色', Color(0xFFFB8C00)),
    MaterialPreset('琥珀色', Color(0xFFFFB300)),
    MaterialPreset('黄色', Color(0xFFFDD835)),
    MaterialPreset('酸橙色', Color(0xFFC0CA33)),
    MaterialPreset('浅绿色', Color(0xFF7CB342)),
    MaterialPreset('绿色', Color(0xFF43A047)),
    MaterialPreset('青色', Color(0xFF00ACC1)),
    MaterialPreset('蓝绿色', Color(0xFF00897B)),
    MaterialPreset('浅蓝色', Color(0xFF039BE5)),
    MaterialPreset('蓝色', Color(0xFF1E88E5)),
    MaterialPreset('靛蓝色', Color(0xFF3949AB)),
    MaterialPreset('紫色', Color(0xFF8E24AA)),
    MaterialPreset('深紫色', Color(0xFF5E35B1)),
    MaterialPreset('蓝灰色', Color(0xFF546E7A)),
    MaterialPreset('棕色', Color(0xFF6D4C41)),
    MaterialPreset('灰色', Color(0xFF757575)),
  ];

  static const customName = '自定义';
}

String paletteVariantLabel(String variant) => _variants[variant] ?? variant;

const _variants = <String, String>{
  'tonalSpot': '经典',
  'expressive': '表达',
  'vibrant': '活力',
  'fidelity': '高保真',
  'content': '内容',
  'rainbow': '彩虹',
  'fruitSalad': '水果',
  'monochrome': '单色',
  'neutral': '中性',
};

/// 四象限圆形色块（Material You 基础颜色预览）。
class QuadrantSwatch extends StatelessWidget {
  const QuadrantSwatch({super.key, required this.seed, required this.size, this.variant = 'tonalSpot'});
  final Color seed;
  final double size;
  final String variant;

  @override
  Widget build(BuildContext context) {
    final s = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      dynamicSchemeVariant: MaterialPalettePicker.variantOf(variant),
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _QuadrantPainter([
            s.primary,
            s.primaryContainer,
            s.primaryFixedDim,
            s.primaryFixed,
          ]),
        ),
      ),
    );
  }
}

class _QuadrantPainter extends CustomPainter {
  _QuadrantPainter(this.colors);
  final List<Color> colors;
  @override
  void paint(Canvas canvas, Size size) {
    final halfW = size.width / 2;
    final halfH = size.height / 2;
    final rects = [
      Rect.fromLTWH(0, 0, halfW, halfH),
      Rect.fromLTWH(halfW, 0, halfW, halfH),
      Rect.fromLTWH(0, halfH, halfW, halfH),
      Rect.fromLTWH(halfW, halfH, halfW, halfH),
    ];
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(rects[i], Paint()..color = colors[i]);
    }
  }

  @override
  bool shouldRepaint(covariant _QuadrantPainter old) => old.colors != colors;
}

/// 与 Android「壁纸与样式 → 基础颜色」一致的四象限圆形色板。
class MaterialPalettePicker extends StatelessWidget {
  const MaterialPalettePicker({
    super.key,
    required this.seed,
    required this.selectedName,
    required this.onSelected,
    this.variant = 'tonalSpot',
    this.compact = false,
  });

  final Color seed;
  final String selectedName;
  final ValueChanged<MaterialPreset> onSelected;
  final String variant;
  final bool compact;

  static DynamicSchemeVariant variantOf(String name) => switch (name) {
        'expressive' => DynamicSchemeVariant.expressive,
        'vibrant' => DynamicSchemeVariant.vibrant,
        'fidelity' => DynamicSchemeVariant.fidelity,
        'content' => DynamicSchemeVariant.content,
        'rainbow' => DynamicSchemeVariant.rainbow,
        'fruitSalad' => DynamicSchemeVariant.fruitSalad,
        'monochrome' => DynamicSchemeVariant.monochrome,
        'neutral' => DynamicSchemeVariant.neutral,
        _ => DynamicSchemeVariant.tonalSpot,
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = <MaterialPreset>[
      ...MaterialPreset.presets,
      MaterialPreset(MaterialPreset.customName, seed),
    ];
    final size = compact ? 56.0 : 64.0;
    return Wrap(
      spacing: compact ? 12 : 20,
      runSpacing: compact ? 12 : 18,
      children: items.map((p) {
        final selected = p.name == selectedName;
        return Semantics(
          button: true,
          selected: selected,
          label: p.name,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => onSelected(p),
            child: SizedBox(
              width: size + (compact ? 20 : 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: size,
                    height: size,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? scheme.primary : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        QuadrantSwatch(seed: p.seed, size: size - 6, variant: variant),
                        if (selected)
                          Container(
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x55000000)),
                            child: const Center(
                              child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10.5 : 14,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                      color: selected ? scheme.primary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 调色面板：基础颜色圆盘 + 动态方案变体。
class PalettePickerPanel extends StatelessWidget {
  const PalettePickerPanel({
    super.key,
    required this.seed,
    required this.selectedName,
    required this.variant,
    required this.onPreset,
    required this.onVariant,
  });

  final Color seed;
  final String selectedName;
  final String variant;
  final ValueChanged<MaterialPreset> onPreset;
  final ValueChanged<String> onVariant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('基础颜色', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text('Material You 经典四象限色板；选择后立即应用整套 M3 配色。',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 18),
        MaterialPalettePicker(
          seed: seed,
          selectedName: selectedName,
          variant: variant,
          onSelected: onPreset,
        ),
        const SizedBox(height: 24),
        Text('动态方案', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _variants.entries.map((e) {
            return M3EChip(
              label: e.value,
              type: M3EChipType.filter,
              selected: variant == e.key,
              onPressed: () => onVariant(e.key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

Future<void> showPalettePickerSheet(
  BuildContext context, {
  required Color seed,
  required String selectedName,
  required String variant,
  required ValueChanged<MaterialPreset> onPreset,
  required ValueChanged<String> onVariant,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    backgroundColor: EtsGlass.on ? Colors.transparent : Theme.of(context).colorScheme.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => _PaletteSheet(
      initialSeed: seed,
      initialName: selectedName,
      initialVariant: variant,
      onPreset: onPreset,
      onVariant: onVariant,
    ),
  );
}

class _PaletteSheet extends StatefulWidget {
  const _PaletteSheet({
    required this.initialSeed,
    required this.initialName,
    required this.initialVariant,
    required this.onPreset,
    required this.onVariant,
  });
  final Color initialSeed;
  final String initialName;
  final String initialVariant;
  final ValueChanged<MaterialPreset> onPreset;
  final ValueChanged<String> onVariant;
  @override
  State<_PaletteSheet> createState() => _PaletteSheetState();
}

class _PaletteSheetState extends State<_PaletteSheet> {
  late Color _seed = widget.initialSeed;
  late String _name = widget.initialName;
  late String _variant = widget.initialVariant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height * 0.88;
    final content = SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('壁纸颜色', style: Theme.of(context).textTheme.headlineMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$_name · ${paletteVariantLabel(_variant)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Material You 基础颜色；选择后立即应用到全部界面。',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 18),
                  PalettePickerPanel(
                    seed: _seed,
                    selectedName: _name,
                    variant: _variant,
                    onPreset: (preset) {
                      setState(() {
                        _seed = preset.seed;
                        _name = preset.name;
                      });
                      widget.onPreset(preset);
                    },
                    onVariant: (variant) {
                      setState(() => _variant = variant);
                      widget.onVariant(variant);
                    },
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('完成'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (!EtsGlass.on) return content;
    return EtsGlass.surface(context: context, radius: 28, child: content);
  }
}
