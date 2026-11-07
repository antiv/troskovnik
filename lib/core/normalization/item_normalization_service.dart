import 'package:drift/drift.dart';

import '../db/database.dart';
import 'item_normalizer.dart';
import 'token_set_matcher.dart';

class ResolvedItem {
  const ResolvedItem({
    required this.canonicalItemId,
    required this.displayName,
    required this.extractedMeasure,
    required this.categoryId,
  });

  final int? canonicalItemId;
  final String displayName;
  final String? extractedMeasure;
  final int? categoryId;
}

/// Koordinator višeslojne determinističke normalizacije artikala (Slojevi 1–3 + UX spajanje).
class ItemNormalizationService {
  ItemNormalizationService(this._db);

  final AppDatabase _db;

  /// Normalizuje i razrešava listu stavki u jednom prolazu (bez N+1 upita).
  Future<List<ResolvedItem>> resolveBatch(
    List<({String name, int? categoryId, bool isUnparsed})> items,
  ) =>
      _resolveBatchInternal(items);

  Future<List<ResolvedItem>> _resolveBatchInternal(
    List<({String name, int? categoryId, bool isUnparsed})> items,
  ) async {
    if (items.isEmpty) return const [];

    await _db.ensureCanonicalDictionarySeeded();

    // Učitaj postojeće kanonske artikle i alijase u memoriju za O(1) pretragu u okviru batch-a.
    final canonicalRows = await _db.select(_db.canonicalItems).get();
    final aliasRows = await _db.select(_db.itemAliases).get();

    final canonicalById = <int, CanonicalCandidate>{
      for (final c in canonicalRows)
        c.id: CanonicalCandidate(
          id: c.id,
          canonicalKey: c.canonicalKey,
          displayName: c.displayName,
          defaultCategoryId: c.defaultCategoryId,
        ),
    };
    final canonicalByKey = <String, CanonicalCandidate>{
      for (final c in canonicalById.values) c.canonicalKey: c,
    };
    final aliasToCanonicalId = <String, int>{
      for (final a in aliasRows) a.cleanedRawName: a.canonicalItemId,
    };

    final normCache = <String, NormalizedItemResult>{};
    final pendingAliases = <String, int>{};
    final pendingCategoryUpdates = <int, int>{};

    // Prvi prolaz (u memoriji): pronađi poklapanja za sve unikatne cleanedKey
    // vrednosti i izdvoj one za koje treba kreirati nov kanonski artikal.
    final newCanonicalsToInsert =
        <String, ({String displayName, int? categoryId})>{};
    final matchedCanonicalKeyByCleaned = <String, String>{};

    for (final it in items) {
      if (it.isUnparsed || it.name.trim().isEmpty) continue;
      final norm =
          normCache.putIfAbsent(it.name, () => ItemNormalizer.normalize(it.name));
      final cleanedKey = norm.cleanedKey;
      if (cleanedKey.isEmpty) continue;

      if (matchedCanonicalKeyByCleaned.containsKey(cleanedKey) ||
          newCanonicalsToInsert.containsKey(cleanedKey)) {
        if (it.categoryId != null &&
            newCanonicalsToInsert.containsKey(cleanedKey) &&
            newCanonicalsToInsert[cleanedKey]!.categoryId == null) {
          newCanonicalsToInsert[cleanedKey] = (
            displayName: newCanonicalsToInsert[cleanedKey]!.displayName,
            categoryId: it.categoryId,
          );
        }
        continue;
      }

      // Sloj 2: Tabelarni rečnik alijasa — O(1) provera u memoriji.
      final matchedId = aliasToCanonicalId[cleanedKey];
      CanonicalCandidate? candidate =
          matchedId != null ? canonicalById[matchedId] : null;

      if (candidate == null) {
        candidate = canonicalByKey[cleanedKey];
        if (candidate != null) {
          aliasToCanonicalId[cleanedKey] = candidate.id;
          pendingAliases[cleanedKey] = candidate.id;
        }
      }

      // Sloj 3: Algoritamsko sparivanje skupova tokena (Token Set Ratio + Levenshtein).
      if (candidate == null) {
        final match = TokenSetMatcher.findBestMatch(
          cleanedKey,
          canonicalById.values,
        );
        if (match != null) {
          candidate = match.candidate;
          aliasToCanonicalId[cleanedKey] = candidate.id;
          pendingAliases[cleanedKey] = candidate.id;
        }
      }

      if (candidate != null) {
        matchedCanonicalKeyByCleaned[cleanedKey] = candidate.canonicalKey;
      } else {
        newCanonicalsToInsert[cleanedKey] = (
          displayName: norm.suggestedDisplayName,
          categoryId: it.categoryId,
        );
        // Dodaj privremenog kandidata u canonicalByKey i canonicalById (sa negativnim ID-jem)
        // kako bi naredne stavke u istom batch-u mogle da se spoje sa njim preko Sloja 3!
        final tempId = -(newCanonicalsToInsert.length);
        final tempCandidate = CanonicalCandidate(
          id: tempId,
          canonicalKey: cleanedKey,
          displayName: norm.suggestedDisplayName,
          defaultCategoryId: it.categoryId,
        );
        canonicalById[tempId] = tempCandidate;
        canonicalByKey[cleanedKey] = tempCandidate;
      }
    }

    // Ako ima novih kanonskih artikala, upiši ih u jednom jedinom batch-u.
    if (newCanonicalsToInsert.isNotEmpty) {
      await _db.batch((b) {
        for (final entry in newCanonicalsToInsert.entries) {
          b.insert(
            _db.canonicalItems,
            CanonicalItemsCompanion.insert(
              canonicalKey: entry.key,
              displayName: entry.value.displayName,
              defaultCategoryId: Value(entry.value.categoryId),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
      });

      // Učitaj stvarne ID-jeve novokreiranih kanonskih artikala u jednom upitu.
      final insertedRows = await (_db.select(_db.canonicalItems)
            ..where((c) => c.canonicalKey.isIn(newCanonicalsToInsert.keys)))
          .get();

      // Ukloni privremene negativne ID-jeve i zameni ih stvarnim iz baze.
      canonicalById.removeWhere((id, _) => id < 0);
      for (final row in insertedRows) {
        final realCandidate = CanonicalCandidate(
          id: row.id,
          canonicalKey: row.canonicalKey,
          displayName: row.displayName,
          defaultCategoryId: row.defaultCategoryId,
        );
        canonicalById[row.id] = realCandidate;
        canonicalByKey[row.canonicalKey] = realCandidate;
        aliasToCanonicalId[row.canonicalKey] = row.id;
        pendingAliases[row.canonicalKey] = row.id;
      }

      // Ažuriraj sve alijase iz istog batch-a koji su preko Sloja 3 pokazivali na privremeni kanonski ključ.
      for (final entry in matchedCanonicalKeyByCleaned.entries) {
        final target = canonicalByKey[entry.value];
        if (target != null && target.id > 0) {
          aliasToCanonicalId[entry.key] = target.id;
          pendingAliases[entry.key] = target.id;
        }
      }
    }

    // Drugi prolaz (u memoriji): sastavi rezultate za svaku stavku i pripremi
    // eventualna ažuriranja podrazumevanih kategorija.
    final results = <ResolvedItem>[];
    for (final it in items) {
      if (it.isUnparsed || it.name.trim().isEmpty) {
        results.add(
          ResolvedItem(
            canonicalItemId: null,
            displayName: it.name,
            extractedMeasure: null,
            categoryId: it.categoryId,
          ),
        );
        continue;
      }

      final norm = normCache[it.name]!;
      final cleanedKey = norm.cleanedKey;
      if (cleanedKey.isEmpty) {
        results.add(
          ResolvedItem(
            canonicalItemId: null,
            displayName: it.name,
            extractedMeasure: norm.extractedMeasure,
            categoryId: it.categoryId,
          ),
        );
        continue;
      }

      final cid = aliasToCanonicalId[cleanedKey];
      var candidate = cid != null ? canonicalById[cid] : canonicalByKey[cleanedKey];
      if (candidate == null || candidate.id <= 0) {
        results.add(
          ResolvedItem(
            canonicalItemId: null,
            displayName: it.name,
            extractedMeasure: norm.extractedMeasure,
            categoryId: it.categoryId,
          ),
        );
        continue;
      }

      if (it.categoryId != null && candidate.defaultCategoryId == null) {
        pendingCategoryUpdates[candidate.id] = it.categoryId!;
        candidate = CanonicalCandidate(
          id: candidate.id,
          canonicalKey: candidate.canonicalKey,
          displayName: candidate.displayName,
          defaultCategoryId: it.categoryId,
        );
        canonicalById[candidate.id] = candidate;
        canonicalByKey[candidate.canonicalKey] = candidate;
      }

      results.add(
        ResolvedItem(
          canonicalItemId: candidate.id,
          displayName: candidate.displayName,
          extractedMeasure: norm.extractedMeasure,
          categoryId: it.categoryId ?? candidate.defaultCategoryId,
        ),
      );
    }

    // Upiši sve nove alijase i podrazumevane kategorije u jednom batch-u.
    if (pendingAliases.isNotEmpty || pendingCategoryUpdates.isNotEmpty) {
      await _db.batch((b) {
        for (final entry in pendingAliases.entries) {
          if (entry.value <= 0) continue;
          b.insert(
            _db.itemAliases,
            ItemAliasesCompanion.insert(
              cleanedRawName: entry.key,
              canonicalItemId: entry.value,
            ),
            mode: InsertMode.insertOrIgnore,
          );
        }
        for (final entry in pendingCategoryUpdates.entries) {
          b.update(
            _db.canonicalItems,
            CanonicalItemsCompanion(defaultCategoryId: Value(entry.value)),
            where: ($CanonicalItemsTable tbl) => tbl.id.equals(entry.key),
          );
        }
      });
    }

    return results;
  }

  /// Osigurava da su sve parsirane stavke u bazi povezane sa kanonskim artiklom.
  /// Brza putanja: ako nema stavki sa `canonical_item_id IS NULL`, završava se odmah.
  Future<void> ensureNormalized() {
    return _db.runSerializedNormalization(() async {
      await _db.ensureCanonicalDictionarySeeded();

      final pendingRows = await (_db.select(_db.lineItems)
            ..where((li) =>
                li.isUnparsed.equals(false) & li.canonicalItemId.isNull()))
          .get();

      if (pendingRows.isEmpty) return;

      final resolved = await _resolveBatchInternal([
        for (final r in pendingRows)
          (
            name: r.name,
            categoryId: r.categoryId,
            isUnparsed: r.isUnparsed,
          ),
      ]);

      await _db.batch((b) {
        for (var i = 0; i < pendingRows.length; i++) {
          final row = pendingRows[i];
          final res = resolved[i];
          if (res.canonicalItemId == null) continue;
          b.update(
            _db.lineItems,
            LineItemsCompanion(
              canonicalItemId: Value(res.canonicalItemId),
              extractedMeasure: Value(res.extractedMeasure),
              categoryId: Value(row.categoryId ?? res.categoryId),
            ),
            where: ($LineItemsTable tbl) => tbl.id.equals(row.id),
          );
        }
      });
    });
  }

  /// Ručno spajanje više kanonskih artikala u jedan kanonski entitet (Human-in-the-Loop).
  /// Preusmerava sve `line_items` zapise i trajno čuva mapiranja u `item_aliases`.
  Future<void> mergeCanonicalItems({
    required int targetCanonicalId,
    required List<int> sourceCanonicalIds,
    String? customDisplayName,
  }) async {
    final sources = sourceCanonicalIds
        .where((id) => id != targetCanonicalId)
        .toSet()
        .toList();
    if (sources.isEmpty && customDisplayName == null) return;

    await _db.transaction(() async {
      final targetRow = await (_db.select(_db.canonicalItems)
            ..where((c) => c.id.equals(targetCanonicalId)))
          .getSingleOrNull();
      if (targetRow == null) return;

      int? mergedCategoryId = targetRow.defaultCategoryId;

      if (sources.isNotEmpty) {
        final sourceRows = await (_db.select(_db.canonicalItems)
              ..where((c) => c.id.isIn(sources)))
            .get();
        for (final s in sourceRows) {
          mergedCategoryId ??= s.defaultCategoryId;
        }

        // Sakupi sve alijase i ključeve izvornih artikala.
        final sourceAliases = await (_db.select(_db.itemAliases)
              ..where((a) => a.canonicalItemId.isIn(sources)))
            .get();
        final sourceLineItems = await (_db.select(_db.lineItems)
              ..where((li) => li.canonicalItemId.isIn(sources)))
            .get();

        final aliasKeysToBind = <String>{
          for (final s in sourceRows) s.canonicalKey,
          for (final a in sourceAliases) a.cleanedRawName,
        };
        for (final li in sourceLineItems) {
          final norm = ItemNormalizer.normalize(li.name);
          if (norm.cleanedKey.isNotEmpty) {
            aliasKeysToBind.add(norm.cleanedKey);
          }
        }

        // Preusmeri sve stavke računa na ciljni kanonski artikal.
        await (_db.update(_db.lineItems)
              ..where((li) => li.canonicalItemId.isIn(sources)))
            .write(
          LineItemsCompanion(
            canonicalItemId: Value(targetCanonicalId),
          ),
        );

        // Ako ciljni artikal ima kategoriju, dodeli je stavkama koje nisu imale kategoriju.
        if (mergedCategoryId != null) {
          await (_db.update(_db.lineItems)
                ..where((li) =>
                    li.canonicalItemId.equals(targetCanonicalId) &
                    li.categoryId.isNull()))
              .write(
            LineItemsCompanion(categoryId: Value(mergedCategoryId)),
          );
        }

        // Obriši stare alijase izvornih artikala i upiši trajna pravila na ciljni artikal.
        await (_db.delete(_db.itemAliases)
              ..where((a) => a.canonicalItemId.isIn(sources)))
            .go();

        for (final key in aliasKeysToBind) {
          await _db.into(_db.itemAliases).insert(
                ItemAliasesCompanion.insert(
                  cleanedRawName: key,
                  canonicalItemId: targetCanonicalId,
                  isUserMerged: const Value(true),
                ),
                mode: InsertMode.insertOrReplace,
              );
        }

        // Obriši spojene izvorne kanonske artikle.
        await (_db.delete(_db.canonicalItems)
              ..where((c) => c.id.isIn(sources)))
            .go();
      }

      final trimmedName = customDisplayName?.trim();
      await (_db.update(_db.canonicalItems)
            ..where((c) => c.id.equals(targetCanonicalId)))
          .write(
        CanonicalItemsCompanion(
          displayName: (trimmedName != null && trimmedName.isNotEmpty)
              ? Value(trimmedName)
              : const Value.absent(),
          defaultCategoryId: Value(mergedCategoryId),
        ),
      );
    });
  }

  /// Izdvaja konkretnu sirovu varijantu naziva (`rawName`) iz postojećeg
  /// kanonskog artikla u poseban kanonski artikal i trajno pamti alijas.
  Future<String> unmergeRawVariant({
    required int canonicalItemId,
    required String rawName,
  }) async {
    return _db.transaction(() async {
      final parent = await (_db.select(_db.canonicalItems)
            ..where((c) => c.id.equals(canonicalItemId)))
          .getSingleOrNull();
      final norm = ItemNormalizer.normalize(rawName);
      final cleaned = norm.cleanedKey;

      var newDisplayName = norm.suggestedDisplayName.trim();
      if (newDisplayName.isEmpty ||
          (parent != null &&
              newDisplayName.toLowerCase() ==
                  parent.displayName.toLowerCase())) {
        newDisplayName = rawName.trim();
      }

      var candidateKey = cleaned.isNotEmpty
          ? cleaned
          : 'split:${rawName.trim().toLowerCase()}';
      if (parent != null && candidateKey == parent.canonicalKey) {
        candidateKey = 'split:${rawName.trim().toLowerCase()}';
      }

      var existingTarget = await (_db.select(_db.canonicalItems)
            ..where((c) => c.canonicalKey.equals(candidateKey)))
          .getSingleOrNull();
      if (existingTarget != null && existingTarget.id == canonicalItemId) {
        candidateKey =
            'split:${rawName.trim().toLowerCase()}:${DateTime.now().millisecondsSinceEpoch}';
        existingTarget = null;
      }

      final int newCanonicalId;
      if (existingTarget != null) {
        newCanonicalId = existingTarget.id;
      } else {
        newCanonicalId = await _db.into(_db.canonicalItems).insert(
              CanonicalItemsCompanion.insert(
                canonicalKey: candidateKey,
                displayName: newDisplayName,
                defaultCategoryId: Value(parent?.defaultCategoryId),
              ),
            );
      }

      if (cleaned.isNotEmpty &&
          (parent == null || cleaned != parent.canonicalKey)) {
        await _db.into(_db.itemAliases).insert(
              ItemAliasesCompanion.insert(
                cleanedRawName: cleaned,
                canonicalItemId: newCanonicalId,
                isUserMerged: const Value(true),
              ),
              mode: InsertMode.insertOrReplace,
            );
      }

      await (_db.update(_db.lineItems)
            ..where((li) =>
                li.canonicalItemId.equals(canonicalItemId) &
                li.name.equals(rawName)))
          .write(
        LineItemsCompanion(canonicalItemId: Value(newCanonicalId)),
      );

      return newDisplayName;
    });
  }
}

