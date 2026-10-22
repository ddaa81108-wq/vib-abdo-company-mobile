/// One server money field after parsing.
///
/// [known] holds the integer exactly as decoded. [invalid] is a fractional
/// number, a string, a `double`, an oversized integer, or any other non-int.
/// It is not a number: [units] is null and nothing may format, sum, or send it.
/// Absence of the field is a null [MoneyValue], which the UI draws as '—'.
///
/// A `double` is never stored. Equality with [int] exists so a valid field
/// still compares with the integer the server sent; an invalid field equals
/// no integer, including 0.
final class MoneyValue {
  const MoneyValue.known(this.units) : invalid = false;

  const MoneyValue.invalid() : units = null, invalid = true;

  /// Shown instead of a figure. Distinct from the dash used for a missing field.
  static const invalidLabel = 'مبلغ غير صالح';

  final int? units;
  final bool invalid;

  bool get isInvalid => invalid;

  bool get isValid => !invalid && units != null;

  /// Integer for a valid field. Invalid and absent stay null and are not 0.
  int? get asInt => isValid ? units : null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is MoneyValue) {
      return invalid == other.invalid && units == other.units;
    }
    if (other is int) return isValid && units == other;
    return false;
  }

  @override
  int get hashCode => invalid ? 0x1A11D : units.hashCode;

  /// The amount is intentionally absent. Logging this object must not reveal it.
  @override
  String toString() => invalid ? 'MoneyInvalid' : 'MoneyValue';
}

/// Encode a money field for a request body.
///
/// A valid integer is sent as that integer. Absence stays null. An invalid
/// field throws and is never written as 0 or omitted as if it were missing.
Object? wireMoney(MoneyValue? value) {
  if (value == null) return null;
  if (value.isInvalid) {
    throw StateError('refusing to encode an invalid amount');
  }
  return value.units;
}
