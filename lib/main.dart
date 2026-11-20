import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'banner_canvas.dart';
import 'planner.dart' as cut;

void main() => runApp(const BannerCut());

class BannerCut extends StatelessWidget {
  const BannerCut({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BannerCut',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
        scaffoldBackgroundColor: paper,
        dividerColor: line,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: paper,
          counterStyle: const TextStyle(fontSize: 0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: line),
          ),
        ),
      ),
      home: const Workspace(),
    );
  }
}

enum _View { material, manual, reference, optimized }

String _cm(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1).replaceAll('.', ',');

String _percent(double value) =>
    '${(value * 100).toStringAsFixed(1).replaceAll('.', ',')}%';

class Workspace extends StatefulWidget {
  const Workspace({super.key});

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  static const _demoSheet = Size(147, 107);
  static const _demoDefects = [
    Rect.fromLTWH(0, 0, 22, 24),
    Rect.fromLTWH(114, 69, 19, 17),
  ];
  static const _picker = MethodChannel('app.bannercut/photo');

  final _workspaceKey = GlobalKey();
  final _form = GlobalKey<FormState>();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _margin = TextEditingController();
  final _limit = TextEditingController();
  late cut.Planner _planner;
  cut.Pattern _pattern = cut.Pattern.tote;
  List<Rect> _defects = [];
  List<cut.Cut> _manual = [];
  bool _rotateManual = false;
  cut.CutPlan? _reference;
  cut.CutPlan? _optimized;
  _View _view = _View.material;
  bool _demo = true;
  bool _picking = false;
  int _photoGeneration = 0;
  ui.Image? _photo;

  @override
  void initState() {
    super.initState();
    _load(demo: true);
    _generate(showResults: false);
  }

  @override
  void dispose() {
    _photo?.dispose();
    for (final controller in [_width, _height, _margin, _limit]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _load({required bool demo}) {
    _photoGeneration++;
    _demo = demo;
    _setPhoto(null);
    final size = demo ? _demoSheet : const Size(150, 100);
    _width.text = _cm(size.width);
    _height.text = _cm(size.height);
    _margin.text = '1';
    _limit.text = '12';
    _pattern = cut.Pattern.tote;
    _defects = demo ? [..._demoDefects] : [];
    _planner = cut.Planner(size, _defects, _pattern, 1);
    _invalidate();
  }

  void _invalidate() {
    _manual = [];
    _rotateManual = false;
    _reference = null;
    _optimized = null;
    _view = _View.material;
  }

  double? _number(String? text) {
    final parsed = (text ?? '').trim().replaceAll(',', '.');
    return RegExp(r'^\d+(\.\d)?$').hasMatch(parsed)
        ? double.tryParse(parsed)
        : null;
  }

  void _changeSettings() {
    setState(() {
      final width = _number(_width.text);
      final height = _number(_height.text);
      final margin = _number(_margin.text);
      final oldSize = _planner.size;
      final size = Size(
        width != null && width >= 10 && width <= 1000 ? width : oldSize.width,
        height != null && height >= 10 && height <= 1000
            ? height
            : oldSize.height,
      );
      _planner = cut.Planner(
        size,
        _defects,
        _pattern,
        margin != null && margin >= 0 && margin <= 5 ? margin : _planner.margin,
      );
      _invalidate();
    });
  }

  void _generate({bool showResults = true}) {
    if (showResults && !(_form.currentState?.validate() ?? false)) return;
    final limit = int.parse(_limit.text.trim());
    final reference = _planner.baseline(limit);
    final optimized = _planner.optimize(limit, initial: reference);
    setState(() {
      _reference = reference;
      _optimized = optimized;
      _view = _View.optimized;
    });
    if (showResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final workspace = _workspaceKey.currentContext;
        if (workspace != null) {
          Scrollable.ensureVisible(
            workspace,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  void _updateDefects(List<Rect> defects) => setState(() {
    _defects = defects;
    _planner = cut.Planner(_planner.size, _defects, _pattern, _planner.margin);
    _invalidate();
  });

  void _addDefect(Rect rect) {
    if (_defects.length >= 20) {
      _notice('Poți marca până la 20 de zone deteriorate.');
      return;
    }
    _updateDefects([..._defects, rect]);
  }

  int get _manualKits => _manual.length ~/ _pattern.pieces.length;

  void _placeManually(Offset origin) {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_manualKits >= int.parse(_limit.text)) {
      _notice('Ai atins numărul maxim de seturi.');
      return;
    }
    final index = _manual.length % _pattern.pieces.length;
    final rect = _planner.pieceAt(index, origin, rotate: _rotateManual);
    if (!_planner.canPlace(rect, _manual)) {
      _notice('Piesa trebuie să încapă în banner, fără suprapuneri.');
      return;
    }
    setState(() {
      _manual = [..._manual, cut.Cut(index, _manualKits + 1, rect)];
      _rotateManual = false;
    });
  }

  void _setPhoto(ui.Image? image) {
    final old = _photo;
    _photo = image;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  Future<void> _importPhoto() async {
    if (_picking) return;
    setState(() => _picking = true);
    final generation = ++_photoGeneration;
    try {
      final data = await _picker.invokeMethod<Uint8List>('pickPhoto');
      if (data == null || !mounted || generation != _photoGeneration) return;
      final buffer = await ui.ImmutableBuffer.fromUint8List(data);
      final ui.ImageDescriptor descriptor;
      try {
        descriptor = await ui.ImageDescriptor.encoded(buffer);
      } catch (_) {
        buffer.dispose();
        rethrow;
      }
      final portrait = descriptor.height > descriptor.width;
      final resize = (portrait ? descriptor.height : descriptor.width) > 1600;
      try {
        final codec = await descriptor.instantiateCodec(
          targetWidth: resize && !portrait ? 1600 : null,
          targetHeight: resize && portrait ? 1600 : null,
        );
        try {
          final frame = await codec.getNextFrame();
          if (!mounted || generation != _photoGeneration) {
            frame.image.dispose();
            return;
          }
          setState(() {
            _setPhoto(frame.image);
            _view = _View.material;
          });
          _notice('Fotografie adăugată. Marchează zonele deteriorate pe plan.');
        } finally {
          codec.dispose();
        }
      } finally {
        descriptor.dispose();
        buffer.dispose();
      }
    } catch (_) {
      if (mounted && generation == _photoGeneration) {
        _notice(
          'Fotografia nu a putut fi deschisă. Încearcă un JPG sau PNG sub 20 MB.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  List<cut.Cut> _ordered(cut.CutPlan plan) => [...plan.cuts]
    ..sort((a, b) {
      final kitOrder = a.kit.compareTo(b.kit);
      return kitOrder != 0 ? kitOrder : a.pieceIndex.compareTo(b.pieceIndex);
    });

  String _cutSize(cut.Cut part) =>
      '${_cm(part.rect.width)} × ${_cm(part.rect.height)} cm';
  String _cutPosition(cut.Cut part) =>
      'X ${_cm(part.rect.left)} cm · Y ${_cm(part.rect.top)} cm';

  Future<void> _copy(cut.CutPlan plan) async {
    final header =
        'BannerCut · ${_pattern.label} · ${plan.kits} set(uri)\n'
        'Origine: colțul stânga-sus. Dimensiunile includ marja de cusătură.\n';
    final rows = _ordered(plan).map(
      (part) =>
          '${part.code} · ${_pattern.pieces[part.pieceIndex].name} · '
          '${_cutSize(part)} · ${_cutPosition(part)}',
    );
    try {
      await Clipboard.setData(
        ClipboardData(text: '$header\n${rows.join('\n')}'),
      );
      if (mounted) _notice('Lista de tăiere a fost copiată.');
    } on PlatformException {
      if (mounted) _notice('Lista nu a putut fi copiată.');
    }
  }

  void _showPart(cut.Cut part) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${part.code} · ${_pattern.pieces[part.pieceIndex].name}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text('Taie la ${_cutSize(part)}'),
            Text(_cutPosition(part)),
            const SizedBox(height: 8),
            const Text(
              'Coordonatele pornesc din colțul stânga-sus al bannerului.',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 850;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 32 : 16,
                      22,
                      wide ? 32 : 16,
                      32,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1220),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _intro(wide),
                            const SizedBox(height: 18),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(width: 318, child: _settings()),
                                  const SizedBox(width: 18),
                                  Expanded(child: _workspace(wide)),
                                ],
                              )
                            else ...[
                              _workspace(wide),
                              const SizedBox(height: 14),
                              _settings(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1220),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: green,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.content_cut_rounded,
                color: lime,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'BannerCut',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -.7,
              ),
            ),
            const Spacer(),
            PopupMenuButton<bool>(
              tooltip: 'Opțiuni proiect',
              icon: const Icon(Icons.more_horiz),
              onSelected: (demo) {
                setState(() => _load(demo: demo));
                if (demo) _generate(showResults: false);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Banner nou')),
                PopupMenuItem(value: true, child: Text('Încarcă exemplul')),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _intro(bool wide) => Container(
    decoration: BoxDecoration(
      color: ink,
      borderRadius: BorderRadius.circular(20),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: wide ? 26 : 18,
      vertical: wide ? 20 : 15,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _demo ? 'Banner demonstrativ' : 'Banner nou',
          style: const TextStyle(
            color: lime,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Planifică tăierea bannerului',
          style: TextStyle(
            color: Colors.white,
            fontSize: wide ? 32 : 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -.75,
          ),
        ),
      ],
    ),
  );

  Widget _settings() => _Panel(
    child: Form(
      key: _form,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Heading(Icons.straighten_rounded, 'Material'),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(child: _field(_width, 'Lățime', 'cm', 10, 1000)),
                const SizedBox(width: 8),
                Expanded(child: _field(_height, 'Înălțime', 'cm', 10, 1000)),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _picking ? null : _importPhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(
                _photo == null ? 'Adaugă fotografie' : 'Schimbă fotografia',
              ),
            ),
            if (_photo != null)
              TextButton(
                onPressed: () => setState(() {
                  _photoGeneration++;
                  _setPhoto(null);
                }),
                child: const Text('Elimină fotografia'),
              ),
            const Text(
              'Pentru aliniere, folosește o fotografie frontală, decupată la marginile bannerului.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(),
            ),
            const _Heading(Icons.layers_outlined, 'Șablon'),
            const SizedBox(height: 11),
            for (final option in cut.Pattern.values) ...[
              _patternChoice(option),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(child: _field(_margin, 'Marjă / latură', 'cm', 0, 5)),
                const SizedBox(width: 8),
                Expanded(
                  child: _field(
                    _limit,
                    'Max. seturi',
                    '',
                    1,
                    25,
                    integer: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                FocusScope.of(context).unfocus();
                _generate();
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
              label: const Text('Optimizează planul'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label,
    String unit,
    int minimum,
    int maximum, {
    bool integer = false,
  }) => TextFormField(
    controller: controller,
    keyboardType: TextInputType.numberWithOptions(decimal: !integer),
    inputFormatters: [
      FilteringTextInputFormatter.allow(
        integer ? RegExp(r'[0-9]') : RegExp(r'[0-9,.]'),
      ),
      LengthLimitingTextInputFormatter(7),
    ],
    decoration: InputDecoration(
      labelText: label,
      suffixText: unit.isEmpty ? null : unit,
    ),
    validator: (text) {
      final value = integer ? int.tryParse((text ?? '').trim()) : _number(text);
      if (value == null || value < minimum || value > maximum) {
        return integer
            ? '$minimum–$maximum'
            : '$minimum–$maximum · max. 1 zecimală';
      }
      return null;
    },
    onChanged: (_) => _changeSettings(),
  );

  Widget _patternChoice(cut.Pattern option) {
    final active = _pattern == option;
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () {
        if (active) return;
        _pattern = option;
        _changeSettings();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xffedf5e1) : Colors.white,
          border: Border.all(color: active ? const Color(0xffadc292) : line),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(
              option == cut.Pattern.tote
                  ? Icons.shopping_bag_outlined
                  : Icons.laptop_mac_outlined,
              color: green,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    option.size,
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            Icon(
              active ? Icons.check_circle : Icons.circle_outlined,
              size: 17,
              color: active ? green : muted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspace(bool wide) {
    final plan = switch (_view) {
      _View.material || _View.manual => cut.CutPlan.empty,
      _View.reference => _reference ?? cut.CutPlan.empty,
      _View.optimized => _optimized ?? cut.CutPlan.empty,
    };
    final editing = _view == _View.material;
    final manual = _view == _View.manual;
    final ready = _optimized != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: _workspaceKey,
          child: _Panel(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: _Heading(
                          Icons.grid_4x4_rounded,
                          'Plan de tăiere',
                        ),
                      ),
                      Text(
                        '${_cm(_planner.size.width)} × ${_cm(_planner.size.height)} cm',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _viewChip('Editează', _View.material, true),
                      _viewChip('Manual', _View.manual, true),
                      _viewChip('Referință', _View.reference, ready),
                      _viewChip('Optimizat', _View.optimized, ready),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: wide ? 345 : 220,
                      child: BannerCanvas(
                        key: ValueKey(_view),
                        sheet: _planner.size,
                        defects: _planner.defects,
                        cuts: manual ? _manual : plan.cuts,
                        photo: _photo,
                        editing: editing,
                        onDefect: _addDefect,
                        onCut: _showPart,
                        onPlace: manual ? _placeManually : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  if (editing) ...[
                    const Text(
                      'Trage pe banner pentru a marca o zonă deteriorată.',
                      style: TextStyle(color: muted, fontSize: 12),
                    ),
                    if (_defects.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final (index, rect) in _defects.indexed)
                            InputChip(
                              label: Text(
                                'D${index + 1} · ${_cm(rect.width)} × ${_cm(rect.height)} cm',
                                style: const TextStyle(fontSize: 11),
                              ),
                              deleteButtonTooltipMessage:
                                  'Șterge zona ${index + 1}',
                              onDeleted: () => _updateDefects(
                                [..._defects]..removeAt(index),
                              ),
                            ),
                        ],
                      ),
                  ] else if (manual)
                    _manualControls()
                  else
                    Text(
                      plan.cuts.isEmpty
                          ? 'Nu încape niciun set complet în acest plan.'
                          : 'Atinge o piesă pentru cote. Zonele hașurate sunt excluse.',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (ready) ...[const SizedBox(height: 12), _comparison()],
        if (plan.cuts.isNotEmpty) ...[
          const SizedBox(height: 12),
          _cutList(plan),
        ],
      ],
    );
  }

  Widget _manualControls() {
    final index = _manual.length % _pattern.pieces.length;
    final part = _pattern.pieces[index];
    final rect = _planner.pieceAt(index, Offset.zero, rotate: _rotateManual);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Următoarea piesă · ${part.name} · ${_cm(rect.width)} × ${_cm(rect.height)} cm',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
        const Text(
          'Atinge locul unde vrei să fie colțul stânga-sus al piesei.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _rotateManual = !_rotateManual),
              icon: const Icon(Icons.rotate_right, size: 17),
              label: const Text('Rotește'),
            ),
            TextButton.icon(
              onPressed: _manual.isEmpty
                  ? null
                  : () => setState(() {
                      _manual = [..._manual]..removeLast();
                      _rotateManual = false;
                    }),
              icon: const Icon(Icons.undo, size: 17),
              label: const Text('Retrage ultima piesă'),
            ),
          ],
        ),
        Text(
          'Seturi complete așezate manual: $_manualKits',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _viewChip(String text, _View view, bool enabled) => ChoiceChip(
    label: Text(text),
    selected: _view == view,
    selectedColor: lime,
    labelStyle: TextStyle(
      fontSize: 12,
      fontWeight: _view == view ? FontWeight.w800 : FontWeight.w500,
    ),
    visualDensity: VisualDensity.compact,
    side: BorderSide(color: _view == view ? Colors.transparent : line),
    showCheckmark: false,
    onSelected: enabled ? (_) => setState(() => _view = view) : null,
  );

  Widget _comparison() {
    final reference = _reference!;
    final optimized = _optimized!;
    final delta = _planner.usage(optimized) - _planner.usage(reference);
    return _Panel(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Heading(Icons.bar_chart_rounded, 'Utilizarea materialului'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _metric('Referință', reference, false)),
                const SizedBox(width: 8),
                Expanded(child: _metric('Optimizat', optimized, true)),
              ],
            ),
            if (_manualKits > 0) ...[
              const SizedBox(height: 8),
              _metric(
                'Manual',
                cut.CutPlan(
                  _manual.take(_manualKits * _pattern.pieces.length).toList(),
                  _manualKits,
                ),
                false,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              delta > 0
                  ? '+${(delta * 100).toStringAsFixed(1).replaceAll('.', ',')} puncte procentuale față de așezarea fără rotații.'
                  : 'Ambele planuri folosesc aceeași suprafață.',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, cut.CutPlan plan, bool highlight) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xffe8f4d5) : paper,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: muted, fontSize: 12)),
        Text(
          _percent(_planner.usage(plan)),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -.8,
          ),
        ),
        Text(
          plan.kits == 1 ? '1 set complet' : '${plan.kits} seturi complete',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
      ],
    ),
  );

  Widget _cutList(cut.CutPlan plan) => _Panel(
    child: ExpansionTile(
      title: const Text(
        'Listă de tăiere',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text('${plan.cuts.length} piese · marjă inclusă'),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextButton.icon(
            onPressed: () => _copy(plan),
            icon: const Icon(Icons.copy_outlined, size: 16),
            label: const Text('Copiază lista'),
          ),
        ),
        for (final part in _ordered(plan))
          ListTile(
            dense: true,
            title: Text(
              '${part.code} · ${_pattern.pieces[part.pieceIndex].name}',
            ),
            subtitle: Text(_cutPosition(part)),
            trailing: Text(_cutSize(part)),
            onTap: () => _showPart(part),
          ),
      ],
    ),
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.icon, this.title);
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: green, size: 19),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(16),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}
