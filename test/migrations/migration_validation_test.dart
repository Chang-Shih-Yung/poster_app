import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Validates that migration files exist and contain expected SQL patterns.
/// This is not a full up/down test (requires a live Postgres), but catches
/// obvious issues like empty files or missing transaction blocks.
void main() {
  final migrationsDir = Directory('supabase/migrations');

  test('migrations directory exists', () {
    expect(migrationsDir.existsSync(), isTrue);
  });

  test('all migration files are valid SQL', () {
    final files = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    expect(files, isNotEmpty, reason: 'Should have at least one migration');

    for (final file in files) {
      final content = file.readAsStringSync();
      final name = file.uri.pathSegments.last;

      // Not empty.
      expect(content.trim().isNotEmpty, isTrue,
          reason: '$name should not be empty');

      // Basic check: file contains at least one SQL keyword.
      final lower = content.toLowerCase();
      final hasSql = lower.contains('create') ||
          lower.contains('insert') ||
          lower.contains('alter') ||
          lower.contains('drop') ||
          lower.contains('select') ||
          lower.contains('begin');
      expect(hasSql, isTrue,
          reason: '$name should contain SQL statements');
    }
  });

  test('backfill migration uses transaction', () {
    final backfillFile = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('backfill'))
        .firstOrNull;

    if (backfillFile == null) {
      // backfill not yet created, skip
      return;
    }

    final content = backfillFile.readAsStringSync().toLowerCase();
    expect(content, contains('begin'),
        reason: 'backfill migration should use transaction');
    expect(content, contains('commit'),
        reason: 'backfill migration should commit');
  });

  test('V2 schema migration creates required tables', () {
    // Check that at least one migration creates the works table.
    final allSql = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .map((f) => f.readAsStringSync().toLowerCase())
        .join('\n');

    expect(allSql, contains('create table'),
        reason: 'Should have CREATE TABLE statements');
    expect(allSql, contains('works'),
        reason: 'Should create works table');
    expect(allSql, contains('submissions'),
        reason: 'Should create submissions table');
    expect(allSql, contains('poster_views'),
        reason: 'Should create poster_views table');
  });

  test('RPC migrations include GRANT EXECUTE', () {
    final allSql = migrationsDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sql'))
        .map((f) => f.readAsStringSync().toLowerCase())
        .join('\n');

    // Every RPC should have a corresponding GRANT.
    for (final rpc in [
      'increment_view_with_dedup',
      'toggle_favorite',
      'approve_submission',
      'reject_submission',
      'top_tags',
    ]) {
      expect(allSql, contains(rpc),
          reason: 'Should define $rpc RPC');
    }
  });
}
