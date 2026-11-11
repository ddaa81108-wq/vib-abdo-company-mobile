import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_api_layer/api_layer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_providers.dart';
import '../../error_handling/error_handler.dart';
import '../../state/section_providers.dart';
import '../../state/theme_controller.dart';
import '../../ui/presentation.dart';
import '../../ui/strings.dart';
import '../../ui/theme.dart';
import '../../ui/tokens.dart';
import '../../ui/widgets/common.dart';
import '../../ui/widgets/section_kit.dart';
import 'masraweya_autosave.dart';
import 'masraweya_share.dart';

/// المصراوية: three cards, inline rows, save when a complete row is left.
///
/// Totals stay on `workTotalUnits` / `remainingUnits` from the server.
/// `editable` and `earliestEditableDate` are displayed as sent. The device
/// does not close the day at 04:00 and does not propagate balances.
class MasraweyaScreen extends ConsumerWidget {
  const MasraweyaScreen({super.key});

  static const screenKey = Key('screen-masraweya');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissions = permissionsOf(ref);
    if (!permissions.canRead(SectionKey.masraweya)) {
      return const ForbiddenPane();
    }
    final day = ref.watch(masraweyaProvider);
    final money = ref.watch(apiLayerProvider).money;
    final canWrite = permissions.canWrite(SectionKey.masraweya);
    final online = ref.watch(onlineProvider);
    final frame = _frameGold(context);
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(AppRadii.md);
    final goldSide = BorderSide(color: frame, width: 1.4);
    final goldBox = OutlineInputBorder(
      borderRadius: radius,
      borderSide: goldSide,
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          border: goldBox,
          enabledBorder: goldBox,
          focusedBorder: OutlineInputBorder(
            borderRadius: radius,
            borderSide: BorderSide(color: frame, width: 2),
          ),
        ),
      ),
      child: SectionTheme(
        child: RefreshIndicator(
          key: const Key('masraweya-refresh'),
          onRefresh: () async {
            ref.invalidate(masraweyaProvider);
            await ref.read(masraweyaProvider.future);
          },
          child: ListView(
            key: screenKey,
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: pagePadding(MediaQuery.sizeOf(context).width),
            children: [
              day.when(
                skipLoadingOnReload: true,
                loading: () => const SkeletonBox(height: 120),
                error: (error, _) => presentFailure(
                  ref.read(errorHandlerProvider).toFailure(error),
                  onRetry: () => ref.invalidate(masraweyaProvider),
                ),
                data: (data) => _DayView(
                  data: data,
                  money: money,
                  canWrite: canWrite,
                  online: online,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

abstract final class _MText {
  static const page = 'صفحة المصراوية';
  static const currentDayChip = 'يوم العمل الحالي';
  static const todayChip = 'اليوم الحالي';
  static const previousDay = 'السابق';
  static const nextDay = 'التالي';
  static const workDate = 'تاريخ العمل';
  static const summary = 'ملخص اليوم';
  static const summaryNote = 'القيم بالجنيه المصري';
  static const box = 'المصراوية';
  static const purchasesToday = 'مشتريات اليوم';
  static const workToday = 'إجمالي شغل اليوم';
  static const fromServer = 'من رد الخادم';
  static const remaining = 'الرصيد المتبقي';
  static const work = 'شغل اليوم';
  static const rowFormula = 'إجمالي الصف = القيمة + العمولة';
  static const seq = 'ت';
  static const value = 'القيمة';
  static const commission = 'العمولة';
  static const rowTotal = 'الإجمالي';
  static const noRows = 'لا توجد صفوف لهذا اليوم.';
  static const status = 'حالة اليوم';
  static const addRow = '+ صف';
  static const share = 'مشاركة الملخص';
  static const saving = 'جارٍ الحفظ…';
  static const saved = 'تم الحفظ';
  static const partial =
      'القيمة مطلوبة. العمولة اختيارية، وإن كُتبت فيجب أن تكون عددًا صحيحًا غير سالب.';
  static const previousInvalid = 'القيمة السابقة عدد صحيح.';
  static const purchasesInvalid = 'مشتريات اليوم عدد صحيح غير سالب.';
  static const offline = 'غير متصل. التعديل لم يُرسل.';
  static const dirty = 'تغييرات لم تُحفظ.';
  static const conflict = 'تعارض النسخة. تعديلك محفوظ ولم يُستبدل.';
  static const retry = 'إعادة الإرسال';
  static const sendMine = 'إرسال تعديلي على النسخة الجديدة';
  static const discard = 'تجاهل تعديلي';
  static const readOnlyDay = 'هذا اليوم للقراءة فقط حسب الخادم.';
  static const serverWindow = 'أقدم تاريخ أرسله الخادم للتعديل';
  static const navBlocked = 'اليوم لم يتغير: هناك تعديل غير محفوظ.';
  static const shareFailed = 'تعذرت مشاركة الملخص.';
}

const _goldFill = sectionButtonGold;

/// Light-mode [sectionGold] is orange. Frames and fields use the button gold.
Color _frameGold(BuildContext context) =>
    context.look.glass ? sectionGold(context) : sectionButtonGold;
const _goldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFFFFD54F), Color(0xFFF5C02E), Color(0xFFE0A800)],
);

const _fieldScroll = EdgeInsets.fromLTRB(16, 96, 16, 160);

class _DayView extends ConsumerStatefulWidget {
  const _DayView({
    required this.data,
    required this.money,
    required this.canWrite,
    required this.online,
  });

  final MasraweyaDayDto data;
  final MoneyFormatter money;
  final bool canWrite;
  final bool online;

  @override
  ConsumerState<_DayView> createState() => _DayViewState();
}

class _DayViewState extends ConsumerState<_DayView> {
  late final MasraweyaAutosave _autosave;
  final _captureKey = GlobalKey();
  final _previousFocus = FocusNode();
  final _purchasesFocus = FocusNode();
  TextEditingController? _previous;
  TextEditingController? _purchases;
  List<_EntryFields> _rows = const [];
  final List<FocusNode> _foci = [];
  String? _boundDate;
  var _binding = false;
  var _leaveScheduled = false;
  int? _seenRow;
  var _seenPrevious = false;
  var _seenPurchases = false;
  String? _navNote;

  MasraweyaDayDto get data => widget.data;
  MoneyFormatter get money => widget.money;

  MasraweyaDayDto get _shown => _autosave.authoritative ?? data;

  bool _editDay(MasraweyaDayDto day) => masraweyaFieldsEditable(
    canWrite: widget.canWrite,
    serverEditable: day.editable,
  );

  bool get _canEdit => _editDay(_shown);

  bool get _onServerToday {
    final today = _shown.today;
    if (today == null) return ref.read(masraweyaDateProvider) == null;
    return _shown.businessDate == today;
  }

  @override
  void initState() {
    super.initState();
    _autosave = MasraweyaAutosave(
      send: (request, meta) async {
        final saved = await ref
            .read(masraweyaActionsProvider)
            .saveDay(request, meta);
        if (mounted) {
          ref.read(masraweyaProvider.notifier).adopt(saved);
        }
        return saved;
      },
    );
    _previousFocus.addListener(_scheduleLeaveCheck);
    _purchasesFocus.addListener(_scheduleLeaveCheck);
    _bind(data);
  }

  @override
  void didUpdateWidget(covariant _DayView old) {
    super.didUpdateWidget(old);
    if (!_editDay(data)) {
      if (_purchases != null || data.businessDate != _boundDate) {
        _binding = true;
        _disposeEdit();
        _binding = false;
        _boundDate = data.businessDate;
        _autosave.bindLoaded(data, _serverDraft(data));
      } else if (_autosave.phase == MasraweyaSavePhase.saved) {
        _autosave.noteServerTotals(data);
      }
      return;
    }
    if (_purchases == null || data.businessDate != _boundDate) {
      _bind(data);
      return;
    }
    if (_autosave.phase == MasraweyaSavePhase.saved) {
      _autosave.noteServerTotals(data);
    }
  }

  void _bind(MasraweyaDayDto day) {
    _binding = true;
    _disposeEdit();
    final editing = _editDay(day);
    if (editing) {
      final editPrevious = day.openingEditable != false;
      if (editPrevious) {
        _previous = TextEditingController(
          text: _digits(day.previousValueUnits),
        );
      }
      _purchases = TextEditingController(text: _digits(day.purchasesUnits));
      _rows = [
        for (final entry in day.entries)
          _listenedRow(
            _EntryFields(
              value: entry.valueUnits,
              commission: entry.commissionUnits,
            ),
          ),
      ];
      _foci.addAll([
        for (var i = 0; i < _rows.length * 2; i++)
          FocusNode()..addListener(_scheduleLeaveCheck),
      ]);
    }
    _boundDate = day.businessDate;
    _seenRow = null;
    _seenPrevious = false;
    _seenPurchases = false;
    _binding = false;
    _autosave.authoritative = day;
    _autosave.bindLoaded(
      day,
      editing ? _draft(summaryLeave: false) : _serverDraft(day),
    );
  }

  MasraweyaDraft _serverDraft(MasraweyaDayDto day) => MasraweyaDraft(
    businessDate: day.businessDate,
    previousText: _digits(day.previousValueUnits),
    previousEditable: false,
    lockedPreviousUnits: day.previousValueUnits?.asInt,
    purchasesText: _digits(day.purchasesUnits),
    rows: [
      for (final entry in day.entries)
        MasraweyaRowDraft(
          valueText: _digits(entry.valueUnits),
          commissionText: _digits(entry.commissionUnits),
        ),
    ],
    summaryLeave: false,
  );

  void _disposeEdit() {
    _previous?.dispose();
    _purchases?.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    for (final node in _foci) {
      node.removeListener(_scheduleLeaveCheck);
      node.dispose();
    }
    _foci.clear();
    _rows = const [];
    _previous = null;
    _purchases = null;
  }

  @override
  void dispose() {
    _binding = true;
    _previousFocus.removeListener(_scheduleLeaveCheck);
    _purchasesFocus.removeListener(_scheduleLeaveCheck);
    _disposeEdit();
    _previousFocus.dispose();
    _purchasesFocus.dispose();
    super.dispose();
  }

  void _scheduleLeaveCheck() {
    if (_binding || _leaveScheduled) return;
    _leaveScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _leaveScheduled = false;
      if (!mounted || _binding) return;
      _evaluateLeave();
    });
  }

  void _evaluateLeave() {
    final row = _focusedRow();
    final previous = _previousFocus.hasFocus;
    final purchases = _purchasesFocus.hasFocus;
    final leftRow = _seenRow != null && _seenRow != row ? _seenRow : null;
    final summaryLeave =
        (_seenPrevious && !previous) || (_seenPurchases && !purchases);
    _seenRow = row;
    _seenPrevious = previous;
    _seenPurchases = purchases;
    if (leftRow == null && !summaryLeave) {
      if (row != null || previous || purchases) _revealFocused();
      return;
    }
    _autosave.noteLeave(
      _draft(summaryLeave: summaryLeave),
      leftRowIndex: leftRow,
      online: widget.online,
    );
    _kick();
    _revealFocused();
  }

  int? _focusedRow() {
    for (var i = 0; i < _foci.length; i++) {
      if (_foci[i].hasFocus) return i ~/ 2;
    }
    return null;
  }

  void _revealFocused() {
    FocusNode? node;
    if (_previousFocus.hasFocus) node = _previousFocus;
    if (_purchasesFocus.hasFocus) node = _purchasesFocus;
    for (final candidate in _foci) {
      if (candidate.hasFocus) node = candidate;
    }
    final current = node;
    if (current == null) return;
    final fieldContext = current.context;
    if (fieldContext == null) return;
    Scrollable.ensureVisible(
      fieldContext,
      alignment: 0.2,
      duration: const Duration(milliseconds: 120),
    );
  }

  void _kick() {
    setState(() {});
    _autosave.pump().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onRowText() {
    if (_binding || !mounted) return;
    setState(() {});
  }

  _EntryFields _listenedRow(_EntryFields row) {
    row.value.addListener(_onRowText);
    row.commission.addListener(_onRowText);
    return row;
  }

  void _addRow() {
    if (!_canEdit) return;
    setState(() {
      final row = _listenedRow(_EntryFields());
      final value = FocusNode()..addListener(_scheduleLeaveCheck);
      final commission = FocusNode()..addListener(_scheduleLeaveCheck);
      _rows = [..._rows, row];
      _foci.add(value);
      _foci.add(commission);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _foci.length < 2) return;
      _foci[_foci.length - 2].requestFocus();
    });
  }

  void _focusNext(FocusNode node) {
    final order = <FocusNode>[
      if (_previous != null) _previousFocus,
      if (_purchases != null) _purchasesFocus,
      ..._foci,
    ];
    final index = order.indexOf(node);
    if (index >= 0 && index + 1 < order.length) {
      order[index + 1].requestFocus();
      return;
    }
    FocusScope.of(context).unfocus();
  }

  MasraweyaDraft _draft({required bool summaryLeave}) {
    final day = _shown;
    return MasraweyaDraft(
      businessDate: day.businessDate,
      previousText: _previous?.text ?? _digits(day.previousValueUnits),
      previousEditable: _previous != null,
      lockedPreviousUnits: day.previousValueUnits?.asInt,
      purchasesText: _purchases?.text ?? _digits(day.purchasesUnits),
      rows: _canEdit
          ? [
              for (final row in _rows)
                MasraweyaRowDraft(
                  valueText: row.value.text,
                  commissionText: row.commission.text,
                ),
            ]
          : [
              for (final entry in day.entries)
                MasraweyaRowDraft(
                  valueText: _digits(entry.valueUnits),
                  commissionText: _digits(entry.commissionUnits),
                ),
            ],
      summaryLeave: summaryLeave,
    );
  }

  Future<void> _shift(int delta) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await _afterFrame();
    await _autosave.pump();
    if (!mounted) return;
    if (_autosave.blocksNavigation) {
      setState(() => _navNote = _MText.navBlocked);
      return;
    }
    final day = _shown;
    final today = day.today;
    if (delta > 0 && ref.read(masraweyaDateProvider) == null) return;
    final next = shiftIsoDate(day.businessDate, delta);
    if (next == null) return;
    if (delta > 0 && today != null && next.compareTo(today) > 0) return;
    setState(() => _navNote = null);
    ref.read(masraweyaDateProvider.notifier).state =
        today != null && next == today ? null : next;
  }

  Future<void> _goToday() async {
    if (ref.read(masraweyaDateProvider) == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _afterFrame();
    await _autosave.pump();
    if (!mounted) return;
    if (_autosave.blocksNavigation) {
      setState(() => _navNote = _MText.navBlocked);
      return;
    }
    setState(() => _navNote = null);
    ref.read(masraweyaDateProvider.notifier).state = null;
  }

  Future<void> _afterFrame() {
    final done = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  Future<void> _retry() async {
    await _autosave.retry();
    if (mounted) setState(() {});
  }

  Future<void> _sendMine() async {
    final fresh = await ref
        .read(apiLayerProvider)
        .masraweya
        .getDay(date: ref.read(masraweyaDateProvider));
    if (!mounted) return;
    _autosave.noteServerTotals(fresh);
    _autosave.adoptFreshVersion(fresh.version);
    _autosave.noteLeave(
      _draft(summaryLeave: true),
      leftRowIndex: null,
      online: widget.online,
    );
    await _autosave.pump();
    if (mounted) setState(() {});
  }

  Future<void> _discard() async {
    final fresh = await ref
        .read(apiLayerProvider)
        .masraweya
        .getDay(date: ref.read(masraweyaDateProvider));
    if (!mounted) return;
    ref.read(masraweyaProvider.notifier).adopt(fresh);
    _bind(fresh);
    setState(() => _navNote = null);
  }

  Future<void> _share() async {
    final render = _captureKey.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return;
    try {
      final injected = ref.read(masraweyaBoundaryCaptureProvider);
      final bytes = injected == null
          ? await captureBoundaryPng(render)
          : await injected(render);
      if (!mounted) return;
      await ref.read(masraweyaSummarySharerProvider)(
        bytes,
        'masraweya-summary.png',
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text(_MText.shareFailed)));
    }
  }

  String? get _statusText {
    if (_autosave.phase == MasraweyaSavePhase.saving) return _MText.saving;
    if (_autosave.announceSaved &&
        _autosave.phase == MasraweyaSavePhase.saved) {
      return _MText.saved;
    }
    if (_autosave.phase == MasraweyaSavePhase.conflict) return _MText.conflict;
    if (_autosave.phase == MasraweyaSavePhase.error) {
      final error = _autosave.lastError;
      if (error == null) return _MText.dirty;
      return ref.read(errorHandlerProvider).toFailure(error).message;
    }
    return switch (_autosave.issue) {
      MasraweyaDraftIssue.partialRow => _MText.partial,
      MasraweyaDraftIssue.previousUnits => _MText.previousInvalid,
      MasraweyaDraftIssue.purchasesUnits => _MText.purchasesInvalid,
      MasraweyaDraftIssue.offline => _MText.offline,
      MasraweyaDraftIssue.none =>
        _autosave.phase == MasraweyaSavePhase.dirty ? _MText.dirty : _navNote,
    };
  }

  String _egp(MoneyValue? units) => money.formatOrDash(units, Currency.egp);

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final summary = _summaryCard(context);
    final work = _workCard(context);
    return PopScope(
      canPop: !_autosave.blocksNavigation,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !mounted) return;
        setState(() => _navNote = _MText.navBlocked);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageCard(context),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: summary),
                const SizedBox(width: AppSpacing.md),
                Expanded(flex: 3, child: work),
              ],
            )
          else ...[
            summary,
            work,
          ],
          if (data.status != null && data.status!.isNotEmpty)
            SectionNote(
              '${_MText.status}: ${dayStatusLabel(data.status)}',
              key: const Key('masraweya-status'),
            ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _pageCard(BuildContext context) {
    final look = context.look;
    final day = _shown;
    final earliest = day.earliestEditableDate;
    final window =
        day.editable != null && earliest != null && earliest.isNotEmpty
        ? '${_MText.serverWindow}: $earliest'
        : null;
    return _goldCard(
      key: const Key('masraweya-page'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _blackPill(_MText.page),
              if (_onServerToday) _palePill(_MText.currentDayChip),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_MText.workDate, style: cairo(12, 700, color: look.muted)),
          const SizedBox(height: 6),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _goldOvalButton(
                key: const Key('masraweya-date-prev'),
                label: _MText.previousDay,
                onPressed: () => _shift(-1),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
                child: Container(
                  key: const Key('masraweya-date'),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: look.card,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: _frameGold(context), width: 1.4),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: LtrText(
                      day.businessDate,
                      style: cairo(15, 800, color: look.ink),
                    ),
                  ),
                ),
              ),
              _goldOvalButton(
                key: const Key('masraweya-date-next'),
                label: _MText.nextDay,
                onPressed: _onServerToday ? null : () => _shift(1),
              ),
              _goldOvalButton(
                key: const Key('masraweya-date-today'),
                label: _MText.todayChip,
                onPressed: _onServerToday ? null : _goToday,
              ),
            ],
          ),
          if (day.editable == false) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _MText.readOnlyDay,
              key: const Key('masraweya-readonly'),
              style: cairo(11, 700, color: look.muted),
            ),
          ],
          if (window != null) ...[
            const SizedBox(height: 2),
            Text(
              window,
              key: const Key('masraweya-server-window'),
              style: cairo(11, 600, color: look.muted),
            ),
          ],
          if (_statusText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _statusText!,
              key: const Key('masraweya-save-status'),
              style: cairo(12, 700, color: look.ink),
            ),
          ],
          if (_autosave.phase == MasraweyaSavePhase.error ||
              _autosave.phase == MasraweyaSavePhase.conflict) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: 8,
              children: [
                if (_autosave.phase == MasraweyaSavePhase.error)
                  _goldOvalButton(
                    key: const Key('masraweya-retry-save'),
                    label: _MText.retry,
                    onPressed: widget.online ? _retry : null,
                  ),
                if (_autosave.phase == MasraweyaSavePhase.conflict)
                  _goldOvalButton(
                    key: const Key('masraweya-send-mine'),
                    label: _MText.sendMine,
                    onPressed: widget.online ? _sendMine : null,
                  ),
                _goldOvalButton(
                  key: const Key('masraweya-discard-edits'),
                  label: _MText.discard,
                  onPressed: _discard,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryCard(BuildContext context) {
    final look = context.look;
    final day = _shown;
    final editing = _canEdit && _purchases != null;
    return _goldCard(
      key: const Key('masraweya-summary'),
      pad: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _blackPill(_MText.summary),
                      const SizedBox(height: 4),
                      Text(
                        _MText.summaryNote,
                        style: cairo(11.5, 500, color: look.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const Key('masraweya-share-summary'),
                  tooltip: _MText.share,
                  onPressed: _share,
                  icon: Icon(Icons.ios_share, color: _frameGold(context)),
                ),
              ],
            ),
          ),
          RepaintBoundary(
            key: _captureKey,
            child: RepaintBoundary(
              key: const Key('masraweya-summary-capture'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryBand(day.businessDate),
                  if (editing && _previous != null)
                    _summaryEditRow(
                      key: const Key('masraweya-previous'),
                      frameKey: const Key('masraweya-value-frame-previous'),
                      fieldKey: const Key('masraweya-previous-field'),
                      label: AppStrings.previousValue,
                      controller: _previous!,
                      focusNode: _previousFocus,
                    )
                  else
                    _summaryPlainRow(
                      key: const Key('masraweya-previous'),
                      frameKey: const Key('masraweya-value-frame-previous'),
                      label: AppStrings.previousValue,
                      value: _egp(day.previousValueUnits),
                    ),
                  if (editing)
                    _summaryEditRow(
                      key: const Key('masraweya-purchases'),
                      frameKey: const Key('masraweya-value-frame-purchases'),
                      fieldKey: const Key('masraweya-purchases-field'),
                      label: _MText.purchasesToday,
                      controller: _purchases!,
                      focusNode: _purchasesFocus,
                    )
                  else
                    _summaryPlainRow(
                      key: const Key('masraweya-purchases'),
                      frameKey: const Key('masraweya-value-frame-purchases'),
                      label: _MText.purchasesToday,
                      value: _egp(day.purchasesUnits),
                    ),
                  _summaryPlainRow(
                    key: const Key('masraweya-work-total'),
                    frameKey: const Key('masraweya-value-frame-work'),
                    label: _MText.workToday,
                    hint: _MText.fromServer,
                    value: _egp(day.workTotalUnits),
                    background: _frameGold(context).withValues(alpha: 0.16),
                    frameFill: _frameGold(context).withValues(alpha: 0.12),
                  ),
                  Offstage(
                    child: _summaryPlainRow(
                      key: const Key('masraweya-adjustment'),
                      frameKey: const Key('masraweya-value-frame-adjustment'),
                      label: AppStrings.adjustment,
                      value: _egp(day.historicalAdjustmentUnits),
                    ),
                  ),
                  _remainingRow(context, day),
                ],
              ),
            ),
          ),
          if (editing) const SizedBox.shrink(key: Key('masraweya-form')),
        ],
      ),
    );
  }

  Widget _summaryBand(String date) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: 10,
      ),
      color: const Color(0xFF0B0B0F),
      child: Row(
        children: [
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                _MText.box,
                style: cairo(14, 800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerEnd,
              child: LtrText(date, style: cairo(13, 700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remainingRow(BuildContext context, MasraweyaDayDto day) {
    final look = context.look;
    final colors = context.statusColors;
    final remaining = day.remainingUnits;
    final negative =
        remaining != null && remaining.isValid && (remaining.units ?? 0) < 0;
    final color = negative
        ? colors.cashNegative
        : (Theme.of(context).extension<AppColors>()?.success ??
              colors.creditText);
    final mint = negative
        ? colors.cashNegative.withValues(alpha: 0.10)
        : const Color(0xFFDCF5E7);
    final mintDark = negative
        ? colors.cashNegative.withValues(alpha: 0.16)
        : const Color(0xFF1A3A2A);
    final wash = look.glass ? mintDark : mint;
    return _summaryValueRow(
      key: const Key('masraweya-remaining'),
      frameKey: const Key('masraweya-value-frame-remaining'),
      label: _MText.remaining,
      hint: _MText.fromServer,
      labelColor: color,
      rowFill: wash,
      frameFill: wash,
      value: FittedBox(
        fit: BoxFit.scaleDown,
        child: MoneyText(
          _egp(day.remainingUnits),
          style: context.textExtras.amount.copyWith(color: color, fontSize: 16),
        ),
      ),
    );
  }

  Widget _workCard(BuildContext context) {
    final look = context.look;
    final day = _shown;
    final editing = _canEdit && _purchases != null;
    final rowCount = editing ? _rows.length : day.entries.length;
    return _goldCard(
      key: const Key('masraweya-work'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _blackPill(_MText.work),
                  const SizedBox(height: 4),
                  Text(
                    _MText.rowFormula,
                    style: cairo(11.5, 500, color: look.muted),
                  ),
                ],
              ),
              if (editing)
                _goldOvalButton(
                  key: const Key('masraweya-add-row'),
                  label: _MText.addRow,
                  onPressed: _addRow,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _WorkTable(
            key: const Key('masraweya-work-table'),
            headers: const [
              _MText.seq,
              _MText.value,
              _MText.commission,
              _MText.rowTotal,
            ],
            footerLabel: _MText.workToday,
            footerValue: _egp(day.workTotalUnits),
            empty: rowCount == 0 ? _MText.noRows : null,
            rows: [
              for (var i = 0; i < rowCount; i++)
                [
                  _seqCell(context, _sequenceLabel(day, i, editing)),
                  if (editing)
                    KeyedSubtree(
                      key: Key('masraweya-entry-$i'),
                      child: _inputCell(
                        fieldKey: Key('masraweya-entry-value-field-$i'),
                        controller: _rows[i].value,
                        focusNode: _foci[i * 2],
                      ),
                    )
                  else
                    KeyedSubtree(
                      key: Key('masraweya-entry-$i'),
                      child: _moneyCell(
                        context,
                        _egp(day.entries[i].valueUnits),
                      ),
                    ),
                  if (editing)
                    KeyedSubtree(
                      key: Key('masraweya-entry-commission-$i'),
                      child: _inputCell(
                        fieldKey: Key('masraweya-entry-commission-field-$i'),
                        controller: _rows[i].commission,
                        focusNode: _foci[i * 2 + 1],
                      ),
                    )
                  else
                    KeyedSubtree(
                      key: Key('masraweya-entry-commission-$i'),
                      child: _moneyCell(
                        context,
                        _egp(day.entries[i].commissionUnits),
                      ),
                    ),
                  KeyedSubtree(
                    key: Key('masraweya-entry-total-$i'),
                    child: _moneyCell(context, _rowTotalLabel(i, editing)),
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }

  /// Screen sum of the two cells. Null stays a dash. Server summary is untouched.
  String _rowTotalLabel(int index, bool editing) {
    final int? units;
    if (editing) {
      final row = _rows[index];
      units = masraweyaRowDisplayUnits(row.value.text, row.commission.text);
    } else {
      final entry = _shown.entries[index];
      units = masraweyaRowDisplayUnits(
        _digits(entry.valueUnits),
        _digits(entry.commissionUnits),
      );
    }
    if (units == null) return AppStrings.dash;
    return money.format(units, Currency.egp);
  }

  String _sequenceLabel(MasraweyaDayDto day, int index, bool editing) {
    if (!editing && index < day.entries.length) {
      final sequence = day.entries[index].sequence;
      if (sequence != null) return '$sequence';
    }
    if (editing &&
        index < data.entries.length &&
        data.entries[index].sequence != null) {
      return '${data.entries[index].sequence}';
    }
    return '${index + 1}';
  }

  Widget _goldCard({required Widget child, Key? key, EdgeInsetsGeometry? pad}) {
    final look = context.look;
    final gold = _frameGold(context);
    return Padding(
      key: key,
      padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.md),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: look.card,
          borderRadius: BorderRadius.circular(AppRadii.card),
          border: Border.all(color: gold, width: 1.4),
        ),
        child: Padding(
          padding: pad ?? const EdgeInsetsDirectional.all(AppSpacing.md),
          child: child,
        ),
      ),
    );
  }

  Widget _blackPill(String text) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 260),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0F),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _frameGold(context).withValues(alpha: 0.7)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: cairo(15, 800, color: Colors.white)),
        ),
      ),
    ),
  );

  Widget _palePill(String text) {
    final look = context.look;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: look.glass
            ? _frameGold(context).withValues(alpha: 0.18)
            : const Color(0xFFFFF3C4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _frameGold(context).withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 4,
        ),
        child: Text(text, style: cairo(11.5, 800, color: look.ink)),
      ),
    );
  }

  Widget _goldOvalButton({
    required String label,
    required VoidCallback? onPressed,
    Key? key,
  }) {
    return ConstrainedBox(
      key: key,
      constraints: const BoxConstraints(maxWidth: 220),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            decoration: BoxDecoration(
              gradient: _goldGradient,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _goldFill.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: cairo(13, 800, color: sectionButtonInk),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryEditRow({
    required Key key,
    required Key frameKey,
    required Key fieldKey,
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    final theme = Theme.of(context);
    return _summaryValueRow(
      key: key,
      frameKey: frameKey,
      label: label,
      value: Theme(
        data: theme.copyWith(
          inputDecorationTheme: theme.inputDecorationTheme.copyWith(
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
          ),
        ),
        child: UnitsField(
          key: fieldKey,
          controller: controller,
          focusNode: focusNode,
          label: '',
          showHint: false,
          dense: true,
          scrollPadding: _fieldScroll,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _focusNext(focusNode),
        ),
      ),
      fitValue: false,
    );
  }

  Widget _summaryPlainRow({
    required Key key,
    required Key frameKey,
    required String label,
    required String value,
    String? hint,
    Color? background,
    Color? frameFill,
  }) {
    return _summaryValueRow(
      key: key,
      frameKey: frameKey,
      label: label,
      hint: hint,
      rowFill: background,
      frameFill: frameFill,
      value: FittedBox(
        fit: BoxFit.scaleDown,
        child: MoneyText(
          value,
          style: context.textExtras.amount.copyWith(
            color: context.look.ink,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  /// Label on the right. The value frame is a fixed box on the physical left.
  Widget _summaryValueRow({
    required Key key,
    required Key frameKey,
    required String label,
    required Widget value,
    String? hint,
    Color? labelColor,
    Color? rowFill,
    Color? frameFill,
    bool fitValue = true,
  }) {
    final look = context.look;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);
    final width = 156.0 * scale;
    final height = 48.0 * scale;
    return Container(
      key: key,
      decoration: BoxDecoration(
        color: rowFill,
        border: Border(bottom: BorderSide(color: look.cardBorder)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: cairo(14, 800, color: labelColor ?? look.ink),
                ),
                if (hint != null)
                  Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: cairo(11, 500, color: look.muted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            key: frameKey,
            width: width,
            height: height,
            clipBehavior: Clip.antiAlias,
            alignment: fitValue ? Alignment.center : null,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: frameFill ?? look.card,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: _frameGold(context), width: 1.4),
            ),
            child: value,
          ),
        ],
      ),
    );
  }

  Widget _seqCell(BuildContext context, String n) => Center(
    child: Text(n, style: cairo(14, 800, color: context.look.ink)),
  );

  Widget _moneyCell(BuildContext context, String value) => Center(
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: MoneyText(value, style: cairo(13, 700, color: context.look.ink)),
    ),
  );

  Widget _inputCell({
    required Key fieldKey,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    final look = context.look;
    return Container(
      decoration: BoxDecoration(
        color: look.card,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: _frameGold(context), width: 1.4),
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
      child: UnitsField(
        key: fieldKey,
        controller: controller,
        label: '',
        showHint: false,
        dense: true,
        focusNode: focusNode,
        textInputAction: TextInputAction.next,
        scrollPadding: _fieldScroll,
        onSubmitted: (_) => _focusNext(focusNode),
      ),
    );
  }
}

class _WorkTable extends StatelessWidget {
  const _WorkTable({
    required this.headers,
    required this.rows,
    required this.footerLabel,
    required this.footerValue,
    this.empty,
    super.key,
  });

  final List<String> headers;
  final List<List<Widget>> rows;
  final String footerLabel;
  final String footerValue;
  final String? empty;

  /// التسلسل stays narrow. القيمة is wide enough for a long integer.
  /// العمولة is narrower. The row total keeps a middle share.
  static const _flex = [2, 8, 2, 3];

  @override
  Widget build(BuildContext context) {
    final look = context.look;
    final gold = _frameGold(context);
    final line = BorderSide(color: gold.withValues(alpha: 0.55));
    Widget cell(int i, Widget child) => Expanded(
      flex: _flex[i],
      child: Container(
        decoration: BoxDecoration(
          border: i == headers.length - 1 ? null : Border(left: line),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 6),
        alignment: Alignment.center,
        child: child,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: gold.withValues(alpha: 0.7)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Column(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0B0B0F)),
              child: Row(
                children: [
                  for (var i = 0; i < headers.length; i++)
                    cell(
                      i,
                      Text(
                        headers[i],
                        textAlign: TextAlign.center,
                        style: cairo(12, 800, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (rows.isEmpty && empty != null)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(empty!, style: cairo(13, 600, color: look.muted)),
              )
            else
              for (final row in rows)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: look.card,
                    border: Border(bottom: BorderSide(color: look.cardBorder)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < row.length; i++) cell(i, row[i]),
                      ],
                    ),
                  ),
                ),
            DecoratedBox(
              key: const Key('masraweya-work-footer'),
              decoration: const BoxDecoration(color: Color(0xFF0B0B0F)),
              child: Row(
                children: [
                  Expanded(
                    flex: _flex[0] + _flex[1] + _flex[2],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Text(
                        footerLabel,
                        style: cairo(12.5, 800, color: Colors.white),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _flex[3],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: MoneyText(
                            footerValue,
                            style: cairo(13, 800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _digits(MoneyValue? value) =>
    value != null && value.isValid ? '${value.units}' : '';

class _EntryFields {
  _EntryFields({MoneyValue? value, MoneyValue? commission})
    : value = TextEditingController(text: _digits(value)),
      commission = TextEditingController(text: _digits(commission));

  final TextEditingController value;
  final TextEditingController commission;

  void dispose() {
    value.dispose();
    commission.dispose();
  }
}
