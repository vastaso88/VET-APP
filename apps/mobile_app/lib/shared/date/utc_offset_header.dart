/// The phone's offset from UTC, in minutes, as the backend wants it
/// (`X-UTC-Offset-Minutes`, e.g. 60 in winter and 120 in summer for Rome).
///
/// The per-owner daily counters (questions, photos, dictations, summaries)
/// start over at the owner's own midnight: the backend works that out from
/// this offset alone, which already includes summer time, so it needs no time
/// zone database and the app no zone name. Sent only on the requests that are
/// counted; an old build that does not send it keeps the UTC day.
const utcOffsetHeaderName = 'X-UTC-Offset-Minutes';

/// The header for the offset holding right now, or for [offset] (tests).
Map<String, String> utcOffsetHeader([Duration? offset]) => {
      utcOffsetHeaderName: (offset ?? DateTime.now().timeZoneOffset).inMinutes.toString(),
    };
