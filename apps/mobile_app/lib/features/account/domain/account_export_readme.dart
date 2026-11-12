import 'dart:convert';

/// The words of the readable page, in the owner's language. Built from the
/// app's localisations (see `account_export_labels.dart`); tests pass their
/// own.
class ExportReadmeLabels {
  const ExportReadmeLabels({
    required this.htmlLang,
    required this.title,
    required this.intro,
    required this.sensitive,
    required this.generatedOn,
    required this.sectionAccount,
    required this.sectionPets,
    required this.petSheet,
    required this.clinicalRecord,
    required this.conditions,
    required this.weights,
    required this.reminders,
    required this.walks,
    required this.media,
    required this.chat,
    required this.attachments,
    required this.marketplace,
    required this.consents,
    required this.subscription,
    required this.location,
    required this.other,
    required this.missing,
    required this.missingIntro,
    required this.empty,
    required this.roleUser,
    required this.roleAssistant,
    required this.yes,
    required this.no,
    required this.routePoints,
    required this.fields,
  });

  final String htmlLang;
  final String title;
  final String intro;
  final String sensitive;
  final String Function(String date) generatedOn;
  final String sectionAccount;
  final String sectionPets;
  final String petSheet;
  final String clinicalRecord;
  final String conditions;
  final String weights;
  final String reminders;
  final String walks;
  final String media;
  final String chat;
  final String attachments;
  final String marketplace;
  final String consents;
  final String subscription;
  final String location;
  final String other;
  final String missing;
  final String missingIntro;
  final String empty;
  final String roleUser;
  final String roleAssistant;
  final String yes;
  final String no;
  final String Function(int count) routePoints;

  /// Column name -> label. Columns that are not here are shown with their
  /// name, underscores turned into spaces.
  final Map<String, String> fields;
}

/// A file of the export that could not be put in the zip.
class MissingExportFile {
  const MissingExportFile({required this.name, required this.reason});

  /// What the owner can recognise: the file name from the storage path.
  final String name;

  /// Short technical reason, never shown as HTML.
  final String reason;
}

typedef ExportDateFormatter = String Function(DateTime date, {required bool withTime});

/// Every piece of text from the data is untrusted (notes, chat messages, pet
/// and listing names): it goes through this escape, `& < > " ' /` included,
/// and is never written as markup.
const _escape = HtmlEscape(HtmlEscapeMode.unknown);

String _e(Object? value) => _escape.convert('$value');

/// For attribute values (paths made by the app): no slash entity, quotes and
/// angle brackets still escaped.
const _attrEscape = HtmlEscape(HtmlEscapeMode.attribute);

String _attr(Object? value) => _attrEscape.convert('$value');

/// Columns that mean nothing to a person (identifiers, storage keys, pseudonyms).
const _hiddenColumns = <String>{
  'id',
  'owner_id',
  'pet_id',
  'conversation_id',
  'attachment_id',
  'storage_key',
  'storage_path',
  'is_profile',
  'reporter_ref',
  'reporter_pseudonym',
  'voter_pseudonym',
  'analysis_failed',
  'detail_source',
  'badge',
  'meta',
  'photo_urls',
};

final _isoDate = RegExp(r'^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$');

const _imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp'};

String _humanize(String column) {
  final text = column.replaceAll('_', ' ').trim();
  if (text.isEmpty) return column;
  return '${text[0].toUpperCase()}${text.substring(1)}';
}

/// The readable page of the export (`leggimi.html`): account, every pet with
/// its record, chat, listings, consents and subscription, with readable
/// dates. It is a plain document: no script, no external resource, a policy
/// that forbids both, and every text escaped.
///
/// [fileLinks] maps a storage path of `export['files']` to the relative path
/// inside the zip (`foto/...`, `allegati/...`) of the files that were
/// downloaded; a file that is not there is listed in [missingFiles].
String renderExportReadme({
  required Map<String, dynamic> export,
  required ExportReadmeLabels labels,
  required Map<String, String> fileLinks,
  required List<MissingExportFile> missingFiles,
  required ExportDateFormatter formatDate,
}) {
  final data = (export['data'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  List<Map<String, dynamic>> rows(String table) => [
        for (final item in (data[table] as List?) ?? const [])
          if (item is Map) item.cast<String, dynamic>(),
      ];

  final used = <String>{};
  List<Map<String, dynamic>> take(String table) {
    used.add(table);
    return rows(table);
  }

  String label(String column) => labels.fields[column] ?? _humanize(column);

  String formatValue(String column, Object? value) {
    if (value is bool) return _e(value ? labels.yes : labels.no);
    if (value is String) {
      if (_isoDate.hasMatch(value)) {
        final date = DateTime.tryParse(value);
        if (date != null) {
          return _e(formatDate(date.toLocal(), withTime: value.length > 10));
        }
      }
      return _e(value);
    }
    if (value is num) {
      if (column == 'price_cents') return _e((value / 100).toStringAsFixed(2));
      return _e(value);
    }
    if (value is List && column == 'route') return _e(labels.routePoints(value.length));
    if (value is Map || value is List) {
      return '<pre>${_e(const JsonEncoder.withIndent('  ').convert(value))}</pre>';
    }
    return _e(value);
  }

  String card(Map<String, dynamic> row, {Set<String> skip = const {}}) {
    final out = StringBuffer('<dl>');
    var any = false;
    for (final entry in row.entries) {
      final column = entry.key;
      final value = entry.value;
      if (_hiddenColumns.contains(column) || skip.contains(column)) continue;
      if (value == null || (value is String && value.trim().isEmpty)) continue;
      if (value is List && value.isEmpty) continue;
      any = true;
      out.write('<dt>${_e(label(column == 'price_cents' ? 'price' : column))}</dt>');
      out.write('<dd>${formatValue(column, value)}</dd>');
    }
    out.write('</dl>');
    return any ? out.toString() : '';
  }

  String fileNode(String? storagePath, {String? shownName}) {
    final link = storagePath == null ? null : fileLinks[storagePath];
    if (link == null) return '';
    final extension = link.contains('.') ? link.split('.').last.toLowerCase() : '';
    final href = _attr(link);
    if (_imageExtensions.contains(extension)) {
      return '<a href="$href"><img class="photo" src="$href" alt="${_e(shownName ?? '')}"></a>';
    }
    return '<p><a href="$href">${_e(shownName ?? link.split('/').last)}</a></p>';
  }

  String section(String title, String body, {int level = 2}) =>
      body.trim().isEmpty ? '' : '<h$level>${_e(title)}</h$level>$body';

  String list(Iterable<Map<String, dynamic>> items, {Set<String> skip = const {}}) =>
      items.map((item) => '<div class="item">${card(item, skip: skip)}</div>').join();

  final out = StringBuffer();

  // --- account ---------------------------------------------------------------
  final account = (export['account'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
  final flatAccount = <String, dynamic>{
    for (final entry in account.entries)
      if (entry.key != 'profile') entry.key: entry.value,
    ...((account['profile'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{}),
  };
  out.write(section(labels.sectionAccount, card(flatAccount)));

  // --- pets ------------------------------------------------------------------
  final pets = take('pet_profiles');
  final events = take('clinical_events');
  final conditions = take('pet_conditions');
  final weights = take('pet_weight_measurements');
  final reminders = take('reminders');
  final walks = take('dog_walks');
  final photos = take('pet_photos');
  final petIds = {for (final pet in pets) '${pet['id']}'};

  List<Map<String, dynamic>> of(List<Map<String, dynamic>> source, String petId) =>
      [for (final row in source) if ('${row['pet_id']}' == petId) row];

  final petsHtml = StringBuffer();
  for (final pet in pets) {
    final id = '${pet['id']}';
    final name = '${pet['name'] ?? ''}'.trim();
    final body = StringBuffer()
      ..write(section(labels.petSheet, card(pet), level: 4))
      ..write(section(labels.clinicalRecord, list(of(events, id)), level: 4))
      ..write(section(labels.conditions, list(of(conditions, id)), level: 4))
      ..write(section(labels.weights, list(of(weights, id)), level: 4))
      ..write(section(labels.reminders, list(of(reminders, id)), level: 4))
      ..write(section(labels.walks, list(of(walks, id)), level: 4));
    final mediaHtml = of(photos, id)
        .map((photo) => fileNode('${photo['storage_path']}', shownName: name))
        .join();
    body.write(section(labels.media, mediaHtml, level: 4));
    petsHtml.write('<section class="pet"><h3>${_e(name.isEmpty ? '—' : name)}</h3>$body</section>');
  }
  out.write(section(labels.sectionPets, petsHtml.toString()));

  // --- chat ------------------------------------------------------------------
  final conversations = take('conversations');
  final chatAttachments = take('chat_attachments');
  final chatHtml = StringBuffer();
  for (final conversation in conversations) {
    final petName = pets
        .where((pet) => '${pet['id']}' == '${conversation['pet_id']}')
        .map((pet) => '${pet['name']}')
        .join();
    final title = '${conversation['title'] ?? ''}'.trim();
    final messages = StringBuffer();
    for (final message in (conversation['messages'] as List?) ?? const []) {
      if (message is Map) {
        final role = '${message['role'] ?? message['sender'] ?? ''}'.toLowerCase();
        final who = role == 'user' || role == 'owner' ? labels.roleUser : labels.roleAssistant;
        final text = message['content'] ?? message['text'] ?? '';
        final stamp = message['created_at'] ?? message['timestamp'];
        final date = stamp is String && _isoDate.hasMatch(stamp) && DateTime.tryParse(stamp) != null
            ? ' <span class="when">${_e(formatDate(DateTime.parse(stamp).toLocal(), withTime: true))}</span>'
            : '';
        messages.write('<p class="msg"><strong>${_e(who)}</strong>$date<br>${_e(text)}</p>');
      } else {
        messages.write('<p class="msg">${_e(message)}</p>');
      }
    }
    final attached = [
      for (final item in chatAttachments)
        if ('${item['conversation_id']}' == '${conversation['id']}') item,
    ];
    final attachedHtml = attached
        .map((item) =>
            fileNode('${item['storage_key']}', shownName: '${item['original_filename'] ?? ''}') +
            card(item, skip: {'original_filename'}))
        .join();
    chatHtml.write('<section class="conversation"><h3>${_e(title.isEmpty ? '—' : title)}'
        '${petName.isEmpty ? '' : ' <span class="when">· ${_e(petName)}</span>'}</h3>'
        '$messages${section(labels.attachments, attachedHtml, level: 4)}</section>');
  }
  out.write(section(labels.chat, chatHtml.toString()));

  // --- listings, consents, subscription, location -------------------------------
  out.write(section(labels.marketplace, list(take('marketplace_listings'))));
  out.write(section(labels.marketplace, list(take('marketplace_listing_reports')), level: 3));

  final consentRows = take('account_consents');
  final consentsHtml = StringBuffer();
  for (final row in consentRows) {
    final consents = row['consents'];
    if (consents is Map) {
      consentsHtml.write('<dl>');
      for (final entry in consents.entries) {
        final value = entry.value;
        final shown = value is Map
            ? ((value['granted'] ?? value['value']) is bool
                ? ((value['granted'] ?? value['value']) as bool ? labels.yes : labels.no)
                : const JsonEncoder().convert(value))
            : value is bool
                ? (value ? labels.yes : labels.no)
                : '$value';
        consentsHtml.write('<dt>${_e(_humanize('${entry.key}'))}</dt><dd>${_e(shown)}</dd>');
      }
      consentsHtml.write('</dl>');
    }
  }
  out.write(section(labels.consents, consentsHtml.toString()));
  out.write(section(labels.subscription, list(take('subscriptions'))));
  out.write(section(labels.location, list(take('user_locations'))));

  // --- everything else the export carries ---------------------------------------
  final otherHtml = StringBuffer();
  for (final entry in data.entries) {
    if (used.contains(entry.key)) continue;
    final items = rows(entry.key);
    if (items.isEmpty) continue;
    otherHtml.write(section(_humanize(entry.key), list(items), level: 3));
  }
  // Rows of the known tables whose pet is not in the list would be lost from
  // the page; they stay complete in dati.json and are said to be there.
  final orphanCount = [events, conditions, weights, reminders, walks, photos]
      .expand((rows) => rows)
      .where((row) => row['pet_id'] != null && !petIds.contains('${row['pet_id']}'))
      .length;
  if (orphanCount > 0) {
    otherHtml.write('<p>${_e(labels.other)}: $orphanCount</p>');
  }
  out.write(section(labels.other, otherHtml.toString()));

  // --- files that did not come ---------------------------------------------------
  if (missingFiles.isNotEmpty) {
    final items = missingFiles.map((file) => '<li>${_e(file.name)} <span class="when">(${_e(file.reason)})</span></li>').join();
    out.write('<h2>${_e(labels.missing)}</h2><p>${_e(labels.missingIntro)}</p><ul>$items</ul>');
  }

  final generated = DateTime.tryParse('${export['generated_at'] ?? ''}');
  final generatedText = generated == null ? '' : labels.generatedOn(formatDate(generated.toLocal(), withTime: true));

  return '<!doctype html>'
      '<html lang="${_e(labels.htmlLang)}"><head><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      // No script and no external resource, whatever the data holds.
      '<meta http-equiv="Content-Security-Policy" '
      'content="default-src \'none\'; img-src \'self\' data: file:; style-src \'unsafe-inline\'">'
      '<title>${_e(labels.title)}</title>'
      '<style>$_css</style></head><body>'
      '<h1>${_e(labels.title)}</h1>'
      '${generatedText.isEmpty ? '' : '<p class="when">${_e(generatedText)}</p>'}'
      '<p>${_e(labels.intro)}</p>'
      '<p class="notice"><strong>${_e(labels.sensitive)}</strong></p>'
      '${out.toString().trim().isEmpty ? '<p>${_e(labels.empty)}</p>' : out}'
      '</body></html>';
}

const _css = 'body{font-family:system-ui,sans-serif;max-width:860px;margin:0 auto;padding:16px;'
    'line-height:1.5;color:#213134;background:#f6f1ea}'
    'h1{font-size:1.7rem}h2{margin-top:2rem;border-bottom:1px solid #d8ccbf;padding-bottom:4px}'
    'h3{margin-bottom:4px}h4{margin:12px 0 4px;color:#35604f}'
    '.notice{background:#e4ede7;border-radius:10px;padding:10px 14px}'
    '.pet,.conversation{background:#fcfaf7;border:1px solid #e6ddd2;border-radius:14px;padding:4px 16px 12px;margin:12px 0}'
    '.item{border-top:1px solid #e6ddd2;padding:4px 0}'
    'dl{display:grid;grid-template-columns:max-content 1fr;gap:2px 12px;margin:6px 0}'
    'dt{color:#52645f}dd{margin:0;word-break:break-word}'
    'pre{white-space:pre-wrap;word-break:break-word;margin:0;font-size:.85rem}'
    '.msg{white-space:pre-wrap;word-break:break-word;margin:8px 0}'
    '.when{color:#5e6e6b;font-size:.85rem}'
    '.photo{max-width:100%;max-height:320px;border-radius:10px;margin:6px 6px 0 0}';
