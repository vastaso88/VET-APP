import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/auth/current_user.dart';
import '../../../shared/config/app_runtime_config_loader.dart';
import '../domain/event_submission.dart';

/// Esito dell'invio di una segnalazione. Il messaggio di [rejected] arriva dal
/// server (spiega all'utente cosa correggere).
sealed class EventSubmissionOutcome {
  const EventSubmissionOutcome();
}

class EventSubmissionSent extends EventSubmissionOutcome {
  const EventSubmissionSent();
}

class EventSubmissionNotSignedIn extends EventSubmissionOutcome {
  const EventSubmissionNotSignedIn();
}

class EventSubmissionLimitReached extends EventSubmissionOutcome {
  const EventSubmissionLimitReached();
}

class EventSubmissionRejected extends EventSubmissionOutcome {
  const EventSubmissionRejected(this.message);

  final String message;
}

class EventSubmissionFailed extends EventSubmissionOutcome {
  const EventSubmissionFailed();
}

/// POST /events/submissions: la segnalazione resta in moderazione, non compare
/// nell'elenco finché il team non l'ha controllata.
class EventSubmissionRepository {
  EventSubmissionRepository({
    http.Client? client,
    AppRuntimeConfigLoader? configLoader,
    String? Function()? accessToken,
  })  : _client = client ?? http.Client(),
        _configLoader = configLoader ?? const AppRuntimeConfigLoader(),
        _accessToken = accessToken ?? CurrentUser.accessToken;

  final http.Client _client;
  final AppRuntimeConfigLoader _configLoader;
  final String? Function() _accessToken;

  static const _timeout = Duration(seconds: 20);

  Future<EventSubmissionOutcome> submit(EventSubmissionDraft draft) async {
    final token = _accessToken();
    if (token == null || token.isEmpty) {
      return const EventSubmissionNotSignedIn();
    }

    try {
      final response = await _client
          .post(
            Uri.parse('${_configLoader.load().apiBaseUrl}/events/submissions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(draft.toJson()),
          )
          .timeout(_timeout);

      if (response.statusCode == 201) return const EventSubmissionSent();
      if (response.statusCode == 401) return const EventSubmissionNotSignedIn();
      if (response.statusCode == 429) return const EventSubmissionLimitReached();
      if (response.statusCode == 400) {
        final detail = (jsonDecode(response.body) as Map<String, dynamic>)['detail'];
        if (detail is String && detail.isNotEmpty) return EventSubmissionRejected(detail);
      }
      return const EventSubmissionFailed();
    } on TimeoutException {
      return const EventSubmissionFailed();
    } catch (_) {
      return const EventSubmissionFailed();
    }
  }
}
