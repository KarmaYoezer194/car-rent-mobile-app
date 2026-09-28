import 'dart:async';
import 'dart:convert';

import 'package:car_rent/core/services/vin_decoder_service.dart';
import 'package:car_rent/features/post_car/models/car_draft.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Minimal `DecodeVinValues` bodies built from real vPIC responses captured
/// while planning this feature.
String _body({String make = '', String model = '', String year = '', required String errorCode}) => jsonEncode({
      'Count': 1,
      'Results': [
        {'Make': make, 'Model': model, 'ModelYear': year, 'ErrorCode': errorCode, 'ErrorText': ''},
      ],
    });

const _goodVin = '1HGCM82633A004352';

void main() {
  group('VIN format check (local, no network)', () {
    test('normalizes case and whitespace', () {
      expect(VinDecoderService.normalize(' 1hgcm82633a 004352 '), _goodVin);
    });

    test('accepts a well-formed VIN', () {
      expect(VinDecoderService.isWellFormed(_goodVin), isTrue);
    });

    test('rejects wrong length and the letters I, O and Q', () {
      expect(VinDecoderService.isWellFormed('ABC123'), isFalse);
      expect(VinDecoderService.isWellFormed('1HGCM82633A00435O'), isFalse);
      expect(VinDecoderService.isWellFormed('1HGCM82633A00435I'), isFalse);
      expect(VinDecoderService.isWellFormed('1HGCM82633A00435Q'), isFalse);
    });

    test('malformed VINs fail without calling the API', () async {
      var called = false;
      final service = VinDecoderService(client: MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }));
      final result = await service.decode('ABC123');
      expect(result.status, VinDecodeStatus.failed);
      expect(called, isFalse);
    });
  });

  group('parse', () {
    test('clean decode (US Honda Accord) is verified, make title-cased', () {
      final r = VinDecoderService.parse(_goodVin, _body(make: 'HONDA', model: 'Accord', year: '2003', errorCode: '0'));
      expect(r.status, VinDecodeStatus.verified);
      expect((r.make, r.model, r.year), ('Honda', 'Accord', 2003));
    });

    test('data with a check-digit error is partial, still pre-fillable', () {
      final r = VinDecoderService.parse(_goodVin, _body(make: 'HONDA', model: 'Accord', year: '2003', errorCode: '1'));
      expect(r.status, VinDecodeStatus.partial);
      expect(r.hasVehicleData, isTrue);
      expect(r.problem, contains('check digit'));
    });

    test('no vehicle data (Thai-market VIN) fails', () {
      final r = VinDecoderService.parse(_goodVin, _body(errorCode: '1,7,11,400'));
      expect(r.status, VinDecodeStatus.failed);
      expect(r.hasVehicleData, isFalse);
    });

    test('invalid JSON or an empty Results list fails', () {
      expect(VinDecoderService.parse(_goodVin, 'not json').status, VinDecodeStatus.failed);
      expect(VinDecoderService.parse(_goodVin, '{"Results": []}').status, VinDecodeStatus.failed);
    });

    test('title-cases makes but keeps acronyms', () {
      expect(VinDecoderService.titleCaseMake('MERCEDES-BENZ'), 'Mercedes-Benz');
      expect(VinDecoderService.titleCaseMake('LAND ROVER'), 'Land Rover');
      expect(VinDecoderService.titleCaseMake('BMW'), 'BMW');
    });
  });

  group('decode failures fall back instead of throwing', () {
    test('non-200 response', () async {
      final service = VinDecoderService(client: MockClient((_) async => http.Response('oops', 503)));
      expect((await service.decode(_goodVin)).status, VinDecodeStatus.failed);
    });

    test('network error', () async {
      final service = VinDecoderService(client: MockClient((_) async => throw http.ClientException('offline')));
      expect((await service.decode(_goodVin)).status, VinDecodeStatus.failed);
    });

    test('timeout', () async {
      final service = VinDecoderService(
        client: MockClient((_) => Completer<http.Response>().future), // never completes
        timeout: const Duration(milliseconds: 50),
      );
      expect((await service.decode(_goodVin)).status, VinDecodeStatus.failed);
    });
  });

  group('CarDraft.vinVerified', () {
    CarDraft verifiedDraft() => CarDraft()
      ..vin = _goodVin
      ..brand = 'Honda'
      ..model = 'Accord'
      ..year = 2003
      ..vinDecode = const VinDecodeResult(
        vin: _goodVin,
        status: VinDecodeStatus.verified,
        make: 'Honda',
        model: 'Accord',
        year: 2003,
      );

    test('true when the decode is clean and the fields still match', () {
      expect(verifiedDraft().vinVerified, isTrue);
    });

    test('false once the owner changes the make, model or year', () {
      expect((verifiedDraft()..brand = 'Toyota').vinVerified, isFalse);
      expect((verifiedDraft()..year = 2004).vinVerified, isFalse);
    });

    test('false once the VIN itself changes', () {
      expect((verifiedDraft()..vin = '1HGCM82633A004353').vinVerified, isFalse);
    });

    test('false for partial decodes and when no VIN was entered', () {
      final partial = verifiedDraft()
        ..vinDecode = const VinDecodeResult(
          vin: _goodVin,
          status: VinDecodeStatus.partial,
          make: 'Honda',
          model: 'Accord',
          year: 2003,
        );
      expect(partial.vinVerified, isFalse);
      expect(CarDraft().vinVerified, isFalse);
    });
  });
}
