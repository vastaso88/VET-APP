import '../../../l10n/l10n.dart';
import 'billing_models.dart';

/// The first renewal of a plan bought on [from]: one month or one year later,
/// on the same day, or on the last day of a shorter month (31 January → 28
/// February), which is how the stores count.
DateTime firstRenewalDate(DateTime from, BillingCycle cycle) {
  final months = cycle == BillingCycle.yearly ? 12 : 1;
  final lastDay = DateTime(from.year, from.month + months + 1, 0);
  final day = from.day < lastDay.day ? from.day : lastDay.day;
  return DateTime(lastDay.year, lastDay.month, day);
}

/// Price, period, date of the renewal and «until you cancel»: the sentence the
/// owner reads right above the button that pays. [price] is the store's own
/// text (currency and taxes of the owner's country), [date] already formatted.
String renewalSentence(
  AppLocalizations l10n, {
  required BillingCycle cycle,
  required String price,
  required String date,
}) =>
    cycle == BillingCycle.yearly
        ? l10n.renewYearly(price, date)
        : l10n.renewMonthly(price, date);
