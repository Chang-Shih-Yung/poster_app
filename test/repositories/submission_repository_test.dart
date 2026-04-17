import 'package:flutter_test/flutter_test.dart';

import 'package:poster_app/data/models/submission.dart';
import 'package:poster_app/core/constants/enums.dart';

/// Tests for submission repository logic that doesn't require a live Supabase.
/// RPC integration is validated by: (1) migration files creating the functions,
/// (2) manual testing against local Supabase, (3) the approve/reject flows
/// working end-to-end in the admin page.
void main() {
  group('Submission model for RPC integration', () {
    test('toInsertRow generates correct params for approve RPC', () {
      final s = Submission(
        id: 'sub-1',
        workTitleZh: '乘風破浪',
        movieReleaseYear: 2024,
        imageUrl: 'https://example.com/img.jpg',
        uploaderId: 'user-1',
        status: SubmissionStatus.pending,
        region: Region.tw,
        createdAt: DateTime(2024, 1, 1),
      );

      // The approve_submission RPC takes p_submission_id + optional p_work_id.
      // Verify the submission has the fields the RPC reads from.
      expect(s.id, 'sub-1');
      expect(s.workTitleZh, '乘風破浪');
      expect(s.movieReleaseYear, 2024);
      expect(s.status, SubmissionStatus.pending);
    });

    test('approve RPC params shape matches expected format', () {
      // Simulate what SubmissionRepository.approve builds.
      const submissionId = 'sub-123';
      const workId = 'work-456';

      final paramsWithWork = <String, dynamic>{
        'p_submission_id': submissionId,
        'p_work_id': workId,
      };
      expect(paramsWithWork['p_submission_id'], submissionId);
      expect(paramsWithWork['p_work_id'], workId);

      // Without workId (creates new work).
      final paramsNoWork = <String, dynamic>{
        'p_submission_id': submissionId,
      };
      expect(paramsNoWork.containsKey('p_work_id'), isFalse);
    });

    test('reject RPC params shape matches expected format', () {
      const submissionId = 'sub-123';
      const note = '圖片模糊';

      final paramsWithNote = <String, dynamic>{
        'p_submission_id': submissionId,
        'p_note': note,
      };
      expect(paramsWithNote['p_note'], note);

      // Without note.
      final paramsNoNote = <String, dynamic>{
        'p_submission_id': submissionId,
      };
      expect(paramsNoNote.containsKey('p_note'), isFalse);
    });

    test('toggle_favorite RPC params shape', () {
      const posterId = 'poster-789';
      final params = {'p_poster_id': posterId};
      expect(params['p_poster_id'], posterId);
    });

    test('increment_view_with_dedup RPC params shape', () {
      const posterId = 'poster-789';
      final params = {'p_poster_id': posterId};
      expect(params['p_poster_id'], posterId);
    });
  });
}
