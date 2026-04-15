import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/providers/supabase_providers.dart';
import '../../data/repositories/poster_upload_repository.dart';

class SubmissionPage extends ConsumerStatefulWidget {
  const SubmissionPage({super.key});

  @override
  ConsumerState<SubmissionPage> createState() => _SubmissionPageState();
}

class _SubmissionPageState extends ConsumerState<SubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _yearController = TextEditingController();
  final _directorController = TextEditingController();
  final _tagsController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageContentType;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _yearController.dispose();
    _directorController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2000,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _imageContentType = file.mimeType ?? 'image/jpeg';
    });
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _toast('請先登入');
      return;
    }
    if (_imageBytes == null) {
      _toast('請先選一張海報圖片');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(posterUploadRepositoryProvider);
      final url = await repo.uploadImage(
        bytes: _imageBytes!,
        contentType: _imageContentType ?? 'image/jpeg',
        userId: user.id,
      );
      await repo.createSubmission(
        title: _titleController.text.trim(),
        year: int.tryParse(_yearController.text.trim()),
        director: _directorController.text.trim().isEmpty
            ? null
            : _directorController.text.trim(),
        tags: _tagsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        posterUrl: url,
        userId: user.id,
      );
      if (!mounted) return;
      _toast('已送出審核，感謝投稿！');
      setState(() {
        _imageBytes = null;
        _imageContentType = null;
      });
      _formKey.currentState!.reset();
      _titleController.clear();
      _yearController.clear();
      _directorController.clear();
      _tagsController.clear();
    } catch (e) {
      _toast('上傳失敗：$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = ref.watch(currentUserProvider) != null;
    if (!signedIn) {
      return const Center(child: Text('請先到「我的」tab 登入才能上傳'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 2 / 3,
              child: InkWell(
                onTap: _submitting ? null : _pickImage,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageBytes == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48),
                              SizedBox(height: 8),
                              Text('點我選圖（最大 10MB）'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(_imageBytes!,
                              fit: BoxFit.contain),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '標題 *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '必填' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yearController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '年份',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 1900 || n > 2100) return '年份格式錯誤';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _directorController,
              decoration: const InputDecoration(
                labelText: '導演',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: 'Tags（逗號分隔，例：科幻, 諾蘭）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_submitting ? '上傳中…' : '送出審核'),
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
