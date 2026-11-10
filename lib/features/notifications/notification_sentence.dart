import 'package:flutter_api_layer/api_layer.dart';

/// Arabic sentence the website speaks and shows (`notificationSentence`).
///
/// Null when the row has no actor and no details, so older fixtures keep
/// their short labels. The server does not send `title` or `body`.
String? notificationSentence(AppNotification note) {
  final actorName = note.actorName.trim();
  if (actorName.isEmpty && note.details.isEmpty) return null;
  final actor = _actor(note);
  final action = note.operationTypeRaw.trim();
  if (action == 'purchases.entry.create' ||
      action == 'purchases.entry.update') {
    return _purchase(note, actor);
  }
  if (action.startsWith('collection.payroll.')) return _payroll(note, actor);
  final subject = _subject(note.details);
  final amount = _amount(note.details);
  final suffix = [amount, subject].where((part) => part.isNotEmpty).join(' ');
  final paymentMode =
      '${note.details['paymentMode'] ?? note.details['mode'] ?? ''}';

  if (action == 'collection.submit') {
    final mode = paymentMode == 'full' ? 'تسديدًا كليًا' : 'تسديدًا جزئيًا';
    return '$actor سجّل $mode${suffix.isEmpty ? '' : ' $suffix'}.';
  }
  if (action == 'collection.unlinked.submit') {
    return '$actor سجّل استلامًا غير مربوط${suffix.isEmpty ? '' : ' $suffix'} وينتظر ربط الإدارة.';
  }
  if (action.endsWith('.payment')) {
    final mode = paymentMode == 'full' ? 'تسديدًا كليًا' : 'تسديدًا جزئيًا';
    return '$actor سجّل $mode${suffix.isEmpty ? '' : ' $suffix'}.';
  }
  if (action.endsWith('.debt')) {
    return '$actor أضاف دينًا${suffix.isEmpty ? '' : ' $suffix'}.';
  }
  if (action.endsWith('.create')) {
    return '$actor نفّذ «${_actionLabel(action)}»${suffix.isEmpty ? '' : ' $suffix'}.';
  }
  if (action.endsWith('.update')) {
    final target = subject.isNotEmpty ? subject : _actionLabel(action);
    return '$actor عدّل $target${amount.isEmpty ? '' : ' $amount'}.';
  }
  if (action.endsWith('.cancel')) {
    final target = subject.isNotEmpty ? subject : '';
    return ('$actor ألغى معاملة $target.').replaceAll(RegExp(r'\s+\.'), '.');
  }
  if (action == 'collection.assign') {
    final ids = note.details['customerIds'];
    final count = ids is List ? ids.length : 0;
    final cards = count == 1 ? 'كارت' : 'كروت';
    return '$actor وجّه ${count == 0 ? '' : '$count '}$cards للتحصيل.'
        .replaceAll(RegExp(r'\s+'), ' ');
  }
  return '$actor نفّذ «${_actionLabel(action)}»${suffix.isEmpty ? '' : ' $suffix'}.';
}

/// Spoken form of a sentence. Currency words replace the short symbols.
String spokenNotificationText(String text) {
  return text
      .replaceAll('د.ل', 'دينار ليبي')
      .replaceAll('ج.م', 'جنيه مصري')
      .replaceAllMapped(RegExp(r'\b\d{1,3}(?:,\d{3})+\b'), (match) {
        return match.group(0)!.replaceAll(',', '');
      });
}

String _actor(AppNotification note) {
  final role = note.actorRole == 'admin' ? 'الإداري' : 'الموظف';
  return '$role ${note.actorName.trim()}';
}

String _subject(Map<String, dynamic> details) {
  final name = details['subjectName'];
  final text = name is String ? name.trim() : '';
  if (text.isEmpty) return '';
  return '${_subjectLabel(details)} $text';
}

String _subjectLabel(Map<String, dynamic> details) {
  return switch ('${details['subjectSection'] ?? ''}') {
    'company_debts' => 'للشركة',
    'libyan_deposits' => 'بحساب الأمانة الليبية',
    'egyptian_deposits' => 'بحساب الأمانة المصرية',
    'purchases' => 'في المشتريات',
    'treasury' => 'في الخزينة',
    _ => 'للعميل',
  };
}

String _amount(Map<String, dynamic> details) {
  final amount = _integer(details['amountUnits']);
  if (amount == null) return '';
  final currency = '${details['subjectSection'] ?? ''}' == 'egyptian_deposits'
      ? 'ج.م'
      : 'د.ل';
  return 'بقيمة ${_grouped(amount)} $currency';
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  return null;
}

String _grouped(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return negative ? '-$out' : out.toString();
}

String _purchase(AppNotification note, String actor) {
  final details = note.details;
  final result = _integer(details['amountUnits']) ?? 0;
  final paid = _integer(details['paidUnits']) ?? 0;
  final consumed = _integer(details['vodafoneConsumedUnits']) ?? 0;
  final label = details['subjectName'] is String
      ? (details['subjectName'] as String).trim()
      : '';
  const reserved = {'تسديد', 'مستهلك فودافون', 'تسديد واستهلاك فودافون'};
  final itemText = label.isNotEmpty && !reserved.contains(label)
      ? ' ($label)'
      : '';
  final parts = <String>[
    if (result != 0) 'شراء$itemText بقيمة ${_grouped(result)} د.ل',
    if (paid != 0) 'تسديد ${_grouped(paid)} د.ل',
    if (consumed != 0) 'استهلاك فودافون ${_grouped(consumed)} ج.م',
  ];
  if (parts.isEmpty) return '$actor سجّل معاملة مشتريات بدون قيمة مالية.';
  return '$actor سجّل ${parts.join('، ')}.';
}

String _payroll(AppNotification note, String actor) {
  final details = note.details;
  final amount = _integer(details['amountUnits']) ?? 0;
  final kind = '${details['payrollKind'] ?? ''}';
  final employee = details['employeeName'] is String
      ? (details['employeeName'] as String).trim()
      : '';
  final reason = details['reason'] is String
      ? (details['reason'] as String).trim()
      : '';
  final target = employee.isEmpty ? '' : ' للموظف $employee';
  final label = kind == 'commission' ? 'عمولة أو مكافأة' : 'سحب';
  final because = reason.isEmpty ? '' : ' بسبب $reason';
  if (note.operationTypeRaw == 'collection.payroll.entry.confirm') {
    return '$actor أكد استلام $label بقيمة ${_grouped(amount)} د.ل$because.';
  }
  if (note.operationTypeRaw == 'collection.payroll.salary.update') {
    return '$actor حدّث المرتب الثابت$target إلى ${_grouped(amount)} د.ل.';
  }
  return '$actor أضاف $label$target بقيمة ${_grouped(amount)} د.ل$because.';
}

String _actionLabel(String action) {
  return _labels[action] ?? action.split('.').join(' ← ');
}

const _labels = {
  'system.first_admin.create': 'إنشاء حساب المدير الأول',
  'customer.create': 'إضافة عميل',
  'customer.debt': 'إضافة دين عميل',
  'customer.payment': 'تسديد عميل',
  'customer.update': 'تعديل بيانات عميل',
  'company.create': 'إضافة شركة',
  'company.debt': 'إضافة دين شركة',
  'company.payment': 'تسديد شركة',
  'libyan_deposit.create': 'إضافة أمانة ليبية',
  'egyptian_deposit.create': 'إضافة أمانة مصرية',
  'treasury.cash.in': 'دخول نقدية للخزينة',
  'treasury.cash.out': 'خروج نقدية من الخزينة',
  'purchases.entry.create': 'إضافة معاملة مشتريات',
  'masraweya.day.save': 'حفظ يوم المصراوية',
  'collection.submit': 'تسجيل استلام',
  'collection.assign': 'توجيه كروت',
};
