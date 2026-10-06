import 'dart:typed_data';

/// Neutralises the GPS location a phone writes into an MP4/MOV, in place and
/// without changing the file's length - so no chunk offset moves and nothing
/// has to be re-encoded. Returns how many location atoms were blanked.
///
/// What it covers:
/// * `moov/udta/©xyz` (Android and most cameras) and the 3GPP `loci` box;
/// * `moov/meta` keyed metadata (iOS): every `keys` entry containing
///   "location" (`com.apple.quicktime.location.ISO6709`, accuracy) and the
///   matching `ilst` item.
///
/// A blanked atom becomes a `free` box (type renamed, payload zeroed), which
/// every parser skips. The recording time and device model stay, as they are
/// not a position; a dedicated GPS track (action cameras) is not touched.
/// Malformed sizes stop the scan quietly: the file is never made worse.
int stripVideoLocationMetadata(Uint8List bytes) {
  final scrubber = _Scrubber(bytes);
  scrubber.scan(0, bytes.length, 'root');
  return scrubber.blanked;
}

const _containers = {'moov', 'udta', 'meta'};

class _Scrubber {
  _Scrubber(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;
  int blanked = 0;

  String _type(int offset) => String.fromCharCodes(bytes.sublist(offset, offset + 4));

  void scan(int start, int end, String parent) {
    // `meta` keeps its keys/ilst pair together, so it is handled as a unit.
    if (parent == 'meta') {
      _scanKeyedMetadata(start, end);
    }

    var offset = start;
    while (offset + 8 <= end) {
      var size = data.getUint32(offset);
      var header = 8;
      if (size == 1) {
        if (offset + 16 > end) return;
        // Two 32-bit reads: getUint64 is not available when compiled for web.
        if (data.getUint32(offset + 8) != 0) return;
        final large = data.getUint32(offset + 12);
        if (large > end - offset) return;
        size = large;
        header = 16;
      } else if (size == 0) {
        size = end - offset;
      }
      if (size < header || offset + size > end) return;

      final type = _type(offset + 4);
      final boxEnd = offset + size;
      final payload = offset + header;

      if (parent == 'udta' && _isLocationBox(offset + 4)) {
        _blank(offset + 4, payload, boxEnd);
      } else if (type == 'meta') {
        final children = _metaChildrenStart(payload, boxEnd);
        if (children != null) scan(children, boxEnd, 'meta');
      } else if (_containers.contains(type)) {
        scan(payload, boxEnd, type);
      }
      offset = boxEnd;
    }
  }

  /// `©xyz` (0xA9 'x' 'y' 'z'), `xyz ` and the 3GPP `loci`.
  bool _isLocationBox(int typeOffset) {
    final type = bytes.sublist(typeOffset, typeOffset + 4);
    final text = String.fromCharCodes(type);
    return (type[0] == 0xA9 && text.substring(1) == 'xyz') || text == 'xyz ' || text == 'loci';
  }

  /// ISO `meta` is a full box (4 bytes of version/flags before its children),
  /// QuickTime's is not. The first child is always `hdlr`, which tells them
  /// apart.
  int? _metaChildrenStart(int payload, int boxEnd) {
    if (payload + 12 <= boxEnd && _type(payload + 8) == 'hdlr') return payload + 4;
    if (payload + 8 <= boxEnd && _type(payload + 4) == 'hdlr') return payload;
    return null;
  }

  void _scanKeyedMetadata(int start, int end) {
    final locationKeyIndexes = <int>{};
    int? ilstStart;
    int? ilstEnd;

    var offset = start;
    while (offset + 8 <= end) {
      final size = data.getUint32(offset);
      if (size < 8 || offset + size > end) return;
      final type = _type(offset + 4);
      if (type == 'keys') {
        _collectLocationKeys(offset + 8, offset + size, locationKeyIndexes);
      } else if (type == 'ilst') {
        ilstStart = offset + 8;
        ilstEnd = offset + size;
      }
      offset += size;
    }

    if (locationKeyIndexes.isEmpty || ilstStart == null || ilstEnd == null) return;
    var item = ilstStart;
    while (item + 8 <= ilstEnd) {
      final size = data.getUint32(item);
      if (size < 8 || item + size > ilstEnd) return;
      if (locationKeyIndexes.contains(data.getUint32(item + 4))) {
        _blank(item + 4, item + 8, item + size);
      }
      item += size;
    }
  }

  /// `keys` payload: version/flags (4), entry count (4), then per entry a
  /// size (4), a namespace such as `mdta` (4) and the key text.
  void _collectLocationKeys(int payload, int end, Set<int> into) {
    if (payload + 8 > end) return;
    final count = data.getUint32(payload + 4);
    var offset = payload + 8;
    for (var index = 1; index <= count && offset + 8 <= end; index++) {
      final size = data.getUint32(offset);
      if (size < 8 || offset + size > end) return;
      final key = String.fromCharCodes(bytes.sublist(offset + 8, offset + size));
      if (key.toLowerCase().contains('location')) into.add(index);
      offset += size;
    }
  }

  void _blank(int typeOffset, int payloadStart, int boxEnd) {
    bytes.setRange(typeOffset, typeOffset + 4, const [0x66, 0x72, 0x65, 0x65]); // 'free'
    bytes.fillRange(payloadStart, boxEnd, 0);
    blanked++;
  }
}
