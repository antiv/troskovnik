import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:troskovnik/core/domain/review_prompter.dart';
import 'package:troskovnik/core/providers/review_prompt_controller.dart';

/// Fake prompter — beleži koliko je puta ocena zatražena.
class _Prompter implements ReviewPrompter {
  _Prompter({this.available = true});

  final bool available;
  int requestCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requestCount++;
}

class _Storage extends Mock implements FlutterSecureStorage {}

/// Storage koji se stvarno ponaša kao mapa (upiši → pročitaj).
_Storage _storageBackedBy(Map<String, String> store) {
  final storage = _Storage();
  when(() => storage.read(key: any(named: 'key')))
      .thenAnswer((i) async => store[i.namedArguments[#key] as String]);
  when(() => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      )).thenAnswer((i) async {
    store[i.namedArguments[#key] as String] =
        i.namedArguments[#value] as String;
  });
  return storage;
}

ProviderContainer _container(_Prompter prompter, Map<String, String> store) {
  final c = ProviderContainer(overrides: [
    reviewPrompterProvider.overrideWithValue(prompter),
    reviewPromptStorageProvider.overrideWithValue(_storageBackedBy(store)),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<ReviewPromptController> _ready(ProviderContainer c) async {
  await c.read(reviewPromptControllerProvider.future);
  return c.read(reviewPromptControllerProvider.notifier);
}

void main() {
  group('ReviewPromptController', () {
    test('ne traži ocenu pre praga', () async {
      final prompter = _Prompter();
      final controller = await _ready(_container(prompter, {}));

      for (var i = 0; i < ReviewPromptController.threshold - 1; i++) {
        await controller.recordSuccessfulScan();
      }

      expect(prompter.requestCount, 0);
    });

    test('traži ocenu tačno na pragu', () async {
      final prompter = _Prompter();
      final controller = await _ready(_container(prompter, {}));

      for (var i = 0; i < ReviewPromptController.threshold; i++) {
        await controller.recordSuccessfulScan();
      }

      expect(prompter.requestCount, 1);
    });

    test('ne pita dva puta', () async {
      final prompter = _Prompter();
      final controller = await _ready(_container(prompter, {}));

      for (var i = 0; i < ReviewPromptController.threshold + 5; i++) {
        await controller.recordSuccessfulScan();
      }

      expect(prompter.requestCount, 1);
    });

    test('ne pita ako sistemski dijalog nije dostupan', () async {
      final prompter = _Prompter(available: false);
      final controller = await _ready(_container(prompter, {}));

      for (var i = 0; i < ReviewPromptController.threshold; i++) {
        await controller.recordSuccessfulScan();
      }

      expect(prompter.requestCount, 0);
    });

    test('nastavlja brojanje iz sačuvanog stanja', () async {
      final prompter = _Prompter();
      final store = {
        'successful_scans_v1': '${ReviewPromptController.threshold - 1}',
      };
      final controller = await _ready(_container(prompter, store));

      await controller.recordSuccessfulScan();

      expect(prompter.requestCount, 1);
    });

    test('poštuje već zabeleženo pitanje iz ranije instalacije', () async {
      final prompter = _Prompter();
      final store = {
        'successful_scans_v1': '${ReviewPromptController.threshold * 2}',
        'review_asked_v1': DateTime(2026).toIso8601String(),
      };
      final controller = await _ready(_container(prompter, store));

      await controller.recordSuccessfulScan();

      expect(prompter.requestCount, 0);
    });
  });
}
