part of 'library_page.dart';

// ---------------------------------------------------------------------------
// Filter sheet with blurred backdrop
// ---------------------------------------------------------------------------

class _BlurredFilterSheet extends ConsumerStatefulWidget {
  const _BlurredFilterSheet({
    required this.initial,
    required this.history,
    required this.onClearHistory,
  });
  final PosterFilter initial;
  final List<String> history;
  final VoidCallback onClearHistory;

  @override
  ConsumerState<_BlurredFilterSheet> createState() =>
      _BlurredFilterSheetState();
}

class _BlurredFilterSheetState extends ConsumerState<_BlurredFilterSheet> {
  late final TextEditingController _searchController;
  late RangeValues _yearRange;
  late Set<String> _selectedTags;
  late List<String> _history;

  static const _yearMin = 1960.0;
  static final _yearMax = DateTime.now().year.toDouble();

  @override
  void initState() {
    super.initState();
    _searchController =
        TextEditingController(text: widget.initial.search ?? '');
    _yearRange = RangeValues(
      widget.initial.yearMin?.toDouble() ?? _yearMin,
      widget.initial.yearMax?.toDouble() ?? _yearMax,
    );
    _selectedTags = widget.initial.tags.toSet();
    _history = List.of(widget.history);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _apply() {
    final ymin = _yearRange.start.round();
    final ymax = _yearRange.end.round();
    final search = _searchController.text.trim();
    Navigator.of(context).pop(
      PosterFilter(
        sortBy: PosterSort.latest,
        search: search.isEmpty ? null : search,
        tags: _selectedTags.toList(),
        yearMin: ymin == _yearMin.round() ? null : ymin,
        yearMax: ymax == _yearMax.round() ? null : ymax,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topTagsAsync = ref.watch(topTagsProvider);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final topInset = MediaQuery.paddingOf(context).top;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: MediaQuery.sizeOf(context).height - topInset,
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: AppTheme.line1)),
          ),
          child: Column(
            children: [
              // Top bar with dismiss arrow.
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 20, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(LucideIcons.chevronDown,
                            size: 22, color: AppTheme.textMute),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const AppText.title('篩選'),
                  ],
                ),
              ),

              // Search input.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.search,
                          size: 18, color: AppTheme.textMute),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          style: Theme.of(context).textTheme.bodyMedium,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            border: InputBorder.none,
                            hintText: '海報、導演、年份…',
                            hintStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: AppTheme.textFaint),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _apply(),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(_searchController.clear),
                          child: Icon(LucideIcons.x,
                              size: 16, color: AppTheme.textMute),
                        ),
                    ],
                  ),
                ),
              ),

              // Recent searches.
              if (_history.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const AppText.small('最近搜尋',
                              tone: AppTextTone.faint),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              widget.onClearHistory();
                              setState(() => _history = const []);
                            },
                            child: const AppText.small('清除',
                                tone: AppTextTone.faint),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _history
                            .map((term) => GestureDetector(
                                  onTap: () => setState(() {
                                    _searchController.text = term;
                                    _searchController.selection =
                                        TextSelection.collapsed(
                                            offset: term.length);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppTheme.chipBg,
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(term,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),

              // Scrollable filters.
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                      20, 16, 20, bottomInset + safeBottom + 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Year range.
                      Row(
                        children: [
                          const AppText.label('年份', tone: AppTextTone.muted),
                          const SizedBox(width: 8),
                          AppText.label(
                            '${_yearRange.start.round()} – ${_yearRange.end.round()}',
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppTheme.text,
                          inactiveTrackColor: AppTheme.line2,
                          thumbColor: AppTheme.text,
                          overlayColor: Colors.white.withValues(alpha: 0.1),
                          rangeThumbShape: const RoundRangeSliderThumbShape(
                              enabledThumbRadius: 7),
                          trackHeight: 2,
                        ),
                        child: RangeSlider(
                          values: _yearRange,
                          min: _yearMin,
                          max: _yearMax,
                          divisions: (_yearMax - _yearMin).toInt(),
                          onChanged: (v) => setState(() => _yearRange = v),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tags.
                      const AppText.label('標籤', tone: AppTextTone.muted),
                      const SizedBox(height: 10),
                      topTagsAsync.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.all(8),
                          child: LinearProgressIndicator(
                            color: AppTheme.text,
                            backgroundColor: AppTheme.line1,
                          ),
                        ),
                        error: (e, _) => Text('載入失敗：$e',
                            style: Theme.of(context).textTheme.bodySmall),
                        data: (tags) => Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags.map((t) {
                            final selected = _selectedTags.contains(t);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (selected) {
                                  _selectedTags.remove(t);
                                } else {
                                  _selectedTags.add(t);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: AppTheme.motionFast,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppTheme.text
                                      : AppTheme.chipBg,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: AppText.body(
                                  t,
                                  color: selected
                                      ? Colors.black
                                      : AppTheme.text,
                                  weight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Buttons.
                      Row(
                        children: [
                          Expanded(
                            child: AppButton.outline(
                              label: '清除',
                              fullWidth: true,
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _yearRange =
                                      RangeValues(_yearMin, _yearMax);
                                  _selectedTags = {};
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: AppButton.primary(
                              label: '套用',
                              fullWidth: true,
                              onPressed: _apply,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
