import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/router/app_router.dart';
import '../../../l10n/l10n.dart';
import 'billing_demo_store.dart';
import 'subscription_required_signal.dart';

/// The two ways the plan can refuse a write, however it reaches the app: the
/// backend answers HTTP `{"code": "subscription_required"}` (402) and
/// `{"code": "plan_limit_reached", "kind": "pets"}` (403); the database
/// (scripts/setup/plan_access_rules.sql, docs/security/11, §4) raises the same
/// two as PostgREST errors (`PT402` / `PT403`) when the app writes to Supabase
/// directly. This file is the single place that recognises them.
enum PlanRefusalKind {
  /// The trial ended and no plan was chosen: the owner goes to the paywall.
  subscriptionRequired,

  /// The plan does not allow more of [PlanAccessRefusal.limitKind].
  planLimitReached,
}

class PlanAccessRefusal {
  const PlanAccessRefusal(this.kind, {this.limitKind, this.limit});

  final PlanRefusalKind kind;

  /// What ran out for [PlanRefusalKind.planLimitReached]: `pets`, ...
  final String? limitKind;

  /// The plan's limit when the answer carries it.
  final int? limit;

  /// The text shown for this refusal: the paywall's own title (the paywall is
  /// opened at the same time) or the generic "plan limit" text, the same ones
  /// the chat already uses for the backend's answers.
  String get message => kind == PlanRefusalKind.subscriptionRequired
      ? appL10n.billingPaywallTitle
      : appL10n.billingPlanLimitReached;
}

const _subscriptionRequired = 'subscription_required';
const _planLimitReached = 'plan_limit_reached';

/// Recognises a refusal in a backend answer (JSON body with `code`; the
/// older `detail: "<code>: ..."` text is accepted too). Null for anything else.
PlanAccessRefusal? planRefusalFromHttp(int statusCode, String body) {
  if (statusCode != 402 && statusCode != 403) return null;
  String? code;
  String? kind;
  int? limit;
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final rawCode = decoded['code'];
      final rawDetail = decoded['detail'];
      code = rawCode is String
          ? rawCode
          : (rawDetail is String ? rawDetail.split(':').first.trim() : null);
      final rawKind = decoded['kind'];
      if (rawKind is String) kind = rawKind;
      final rawLimit = decoded['limit'];
      if (rawLimit is int) limit = rawLimit;
    }
  } catch (_) {
    return null; // Non-JSON body (a plain 502 from a proxy).
  }
  if (statusCode == 402 && (code == null || code == _subscriptionRequired)) {
    return const PlanAccessRefusal(PlanRefusalKind.subscriptionRequired);
  }
  if (statusCode == 403 && code == _planLimitReached) {
    return PlanAccessRefusal(PlanRefusalKind.planLimitReached, limitKind: kind, limit: limit);
  }
  return null;
}

/// Recognises a refusal in an error thrown by a direct Supabase write.
///
/// * PostgREST 402 / `PT402` / `subscription_required` -> subscription.
/// * PostgREST 403 / `PT403` / `plan_limit_reached` (details = what, hint = the
///   limit) -> plan limit. A plain 403 (`42501`, a row-level-security refusal
///   of someone else's row) is NOT a plan refusal.
/// * A Storage 403 on `pet-photos` counts as subscription_required only when the
///   account has no access ([hasAccess] false): the Storage answer carries no
///   code of its own, so the account state is what tells it apart from any
///   other refusal.
PlanAccessRefusal? planRefusalFromError(
  Object error, {
  bool storagePetPhotos = false,
  bool? hasAccess,
}) {
  if (error is PostgrestException) {
    final code = error.code;
    final message = error.message;
    if (code == 'PT402' || message == _subscriptionRequired) {
      return const PlanAccessRefusal(PlanRefusalKind.subscriptionRequired);
    }
    if (message == _planLimitReached) {
      return PlanAccessRefusal(
        PlanRefusalKind.planLimitReached,
        limitKind: error.details is String ? error.details as String : null,
        limit: int.tryParse(error.hint ?? ''),
      );
    }
    return null;
  }
  if (error is StorageException && storagePetPhotos) {
    final noAccess = !(hasAccess ?? BillingDemoStore.instance.hasAccess);
    if (error.statusCode == '403' && noAccess) {
      return const PlanAccessRefusal(PlanRefusalKind.subscriptionRequired);
    }
  }
  return null;
}

/// Acts on a recognised refusal: a lapsed subscription replaces the whole
/// navigation stack with the paywall (same as at start-up); a plan limit shows
/// its message when [showMessage] (callers that show their own text pass false).
void applyPlanRefusal(PlanAccessRefusal refusal, {bool showMessage = false}) {
  if (refusal.kind == PlanRefusalKind.subscriptionRequired) {
    handleSubscriptionRequired(402);
    return;
  }
  if (showMessage) {
    AppRouter.scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(refusal.message)),
    );
  }
}

/// Recognises and acts in one go, for the `catch` of a direct write. Returns
/// the refusal (so the caller can use [PlanAccessRefusal.message] instead of
/// its generic "not synced" text) or null when [error] is something else.
PlanAccessRefusal? handlePlanRefusal(
  Object error, {
  bool storagePetPhotos = false,
  bool showMessage = false,
}) {
  final refusal = planRefusalFromError(error, storagePetPhotos: storagePetPhotos);
  if (refusal != null) applyPlanRefusal(refusal, showMessage: showMessage);
  return refusal;
}

/// Thrown by an upload whose write the plan refused, after the owner has been
/// sent to the paywall (or shown the limit): lets the caller word its own
/// failure with [PlanAccessRefusal.message] instead of a generic one.
class PlanAccessRefusedException implements Exception {
  const PlanAccessRefusedException(this.refusal);

  final PlanAccessRefusal refusal;

  @override
  String toString() => 'PlanAccessRefusedException(${refusal.kind.name})';
}

/// Like [planRefusalFromError], for the `catch` of an upload that can wait
/// for the account state. A Storage 403 on `pet-photos` carries no code, so
/// when the app still believes the account has access (or has not loaded its
/// state yet) the state is refreshed ONCE from `/subscription/status` before
/// deciding: a trial that ended while the app was open then reaches the paywall.
/// [refreshStatus] is replaceable for tests.
Future<PlanAccessRefusal?> resolvePlanRefusal(
  Object error, {
  bool storagePetPhotos = false,
  Future<void> Function()? refreshStatus,
}) async {
  final known = planRefusalFromError(error, storagePetPhotos: storagePetPhotos);
  if (known != null) return known;
  final storageForbidden =
      error is StorageException && storagePetPhotos && error.statusCode == '403';
  if (!storageForbidden) return null;
  try {
    await (refreshStatus ?? () => BillingDemoStore.instance.syncFromBackend())();
  } catch (_) {
    return null; // Unreachable backend: stay with the ordinary failure.
  }
  return planRefusalFromError(error, storagePetPhotos: true);
}
