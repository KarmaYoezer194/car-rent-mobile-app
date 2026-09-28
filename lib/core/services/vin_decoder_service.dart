import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// How a VIN decode turned out.
enum VinDecodeStatus {
  /// vPIC decoded it cleanly (`ErrorCode` "0") with make, model and year.
  verified,

  /// vPIC returned some vehicle data but flagged a problem (e.g. a check
  /// digit that doesn't compute) — worth pre-filling, not worth vouching for.
  partial,

  /// Malformed VIN, no usable data, or the request itself failed (network,
  /// timeout, bad response). The listing carries on without it.
  failed,
}

class VinDecodeResult {
  const VinDecodeResult({
    required this.vin,
    required this.status,
    this.make = '',
    this.model = '',
    this.year,
    this.problem,
  });

  const VinDecodeResult.failed(this.vin, {this.problem})
      : status = VinDecodeStatus.failed,
        make = '',
        model = '',
        year = null;

  /// The normalized VIN this result is for — lets callers discard a result
  /// that arrives after the user has already typed a different VIN.
  final String vin;
  final VinDecodeStatus status;
  final String make;
  final String model;
  final int? year;

  /// Short, user-facing reason for a [VinDecodeStatus.partial] result.
  final String? problem;

  bool get hasVehicleData => make.isNotEmpty || model.isNotEmpty || year != null;
}

/// Decodes VINs with NHTSA's free vPIC API (no API key; sends
/// `Access-Control-Allow-Origin: *`, so it works from Flutter Web as well
/// as Android/iOS) — called straight from the client, since this app has
/// no backend of its own.
///
/// vPIC only knows vehicles sold in the US: most Thai-market VINs come back
/// with no make/model/year at all, which lands in [VinDecodeStatus.failed]
/// and the owner simply fills the fields in by hand. Never throws — every
/// failure mode becomes a `failed` result, so the Post Car form can't be
/// blocked or crashed by it.
class VinDecoderService {
  VinDecoderService({http.Client? client, this.timeout = const Duration(seconds: 8)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration timeout;

  static final _vinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  /// Uppercased, whitespace-stripped form of what the user typed.
  static String normalize(String input) => input.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// 17 characters, letters and digits only, never I/O/Q (VINs exclude them
  /// to avoid confusion with 1/0). Checked locally, before any network call.
  static bool isWellFormed(String vin) => _vinPattern.hasMatch(vin);

  Future<VinDecodeResult> decode(String input) async {
    final vin = normalize(input);
    if (!isWellFormed(vin)) return VinDecodeResult.failed(vin);

    try {
      final response = await _client
          .get(Uri.parse('https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/$vin?format=json'))
          .timeout(timeout);
      if (response.statusCode != 200) return VinDecodeResult.failed(vin);
      return parse(vin, response.body);
    } catch (_) {
      // Network error, timeout, TLS failure... all the same to the user.
      return VinDecodeResult.failed(vin);
    }
  }

  /// Turns a `DecodeVinValues` JSON body into a result. Public so it can be
  /// unit-tested against captured real responses.
  static VinDecodeResult parse(String vin, String body) {
    Map<String, dynamic> row;
    try {
      final results = (jsonDecode(body) as Map<String, dynamic>)['Results'] as List<dynamic>;
      if (results.isEmpty) return VinDecodeResult.failed(vin);
      row = results.first as Map<String, dynamic>;
    } catch (_) {
      return VinDecodeResult.failed(vin);
    }

    String field(String key) => (row[key] as String? ?? '').trim();

    final make = titleCaseMake(field('Make'));
    final model = field('Model');
    final year = int.tryParse(field('ModelYear'));
    final errorCodes = field('ErrorCode').split(',').map((c) => c.trim()).where((c) => c.isNotEmpty).toSet();

    final hasAll = make.isNotEmpty && model.isNotEmpty && year != null;
    final hasAny = make.isNotEmpty || model.isNotEmpty || year != null;

    if (hasAll && errorCodes.length == 1 && errorCodes.first == '0') {
      return VinDecodeResult(vin: vin, status: VinDecodeStatus.verified, make: make, model: model, year: year);
    }
    if (hasAny) {
      return VinDecodeResult(
        vin: vin,
        status: VinDecodeStatus.partial,
        make: make,
        model: model,
        year: year,
        problem: errorCodes.contains('1') ? "the check digit doesn't match" : "it couldn't be fully decoded",
      );
    }
    return VinDecodeResult.failed(vin);
  }

  /// vPIC returns makes in capitals ("HONDA", "MERCEDES-BENZ"); show them
  /// the way people write them ("Honda", "Mercedes-Benz"), keeping real
  /// acronyms ("BMW") intact.
  static String titleCaseMake(String raw) {
    const acronyms = {'BMW', 'GMC', 'MG', 'BYD', 'GAC', 'JAC', 'VW', 'MINI'};
    if (raw.isEmpty) return raw;
    return raw.split(' ').map((word) {
      return word.split('-').map((part) {
        if (part.isEmpty) return part;
        final upper = part.toUpperCase();
        if (acronyms.contains(upper)) return upper;
        return upper[0] + upper.substring(1).toLowerCase();
      }).join('-');
    }).join(' ');
  }
}
