import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/location_controller.dart';
import '../data/saved_locations_store.dart';
import '../models/location_entry.dart';
import '../widgets/app_dialog.dart';
import '../widgets/skeleton.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = Get.find<LocationController>();
  final _textController = ShadTextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Start from a clean slate rather than the previous visit's results.
    _controller.search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _query = value.trim());
    // Wait for a pause in typing instead of hitting the API per keystroke.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _controller.search(value),
    );
  }

  bool _isSaved(LocationEntry entry) => _controller.savedLocations.any(
    (l) => l.label == entry.location && l.groupCode == entry.groupCode,
  );

  Future<void> _select(LocationEntry entry) async {
    final toaster = ShadToaster.of(context);
    if (_controller.savedLocations.length >= SavedLocationsStore.maxSaved) {
      toaster.show(
        const ShadToast(
          description: Text(
            'You can save up to ${SavedLocationsStore.maxSaved} locations - '
            'remove one first.',
          ),
        ),
      );
      return;
    }
    final nickname = await showAppDialog<String>(
      context: context,
      builder: (context) => _NicknameDialog(locationName: entry.location),
    );
    if (nickname == null || !mounted) return;

    final result = await _controller.saveLocation(entry, customName: nickname);
    if (!mounted) return;
    switch (result) {
      case SaveResult.added:
        Get.back();
        toaster.show(
          ShadToast(
            description: Text(
              '${nickname.trim().isEmpty ? entry.location : nickname.trim()} '
              'added.',
            ),
          ),
        );
      case SaveResult.alreadySaved:
        toaster.show(const ShadToast(description: Text('Already saved.')));
      case SaveResult.limitReached:
        toaster.show(
          const ShadToast(
            description: Text(
              'You can save up to ${SavedLocationsStore.maxSaved} locations - '
              'remove one first.',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a location'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadInput(
              controller: _textController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              placeholder: const Text('Search your neighbourhood or area'),
              leading: const Icon(LucideIcons.search, size: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              style: const TextStyle(fontSize: 16),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            Text(
              'Locations and groups follow ESCOM\'s own published '
              'categorisation, not a general address lookup.',
              style: theme.textTheme.muted.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                // The page draws behind the navigation bar, so the last
                // result needs that much extra room to scroll clear of it.
                final listPadding = EdgeInsets.only(
                  bottom: 16 + MediaQuery.paddingOf(context).bottom,
                );
                if (_controller.isSearching.value) {
                  return ListView.separated(
                    padding: listPadding,
                    itemCount: 6,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => const ShadCard(
                      padding: EdgeInsets.all(12),
                      child: SearchResultSkeleton(),
                    ),
                  );
                }
                if (_controller.searchFailed.value) {
                  return _Message(
                    icon: LucideIcons.wifiOff,
                    title: 'Couldn\'t search',
                    body: 'Check your connection and try again.',
                    action: ShadButton.outline(
                      onPressed: () => _controller.search(_query),
                      child: const Text('Retry'),
                    ),
                  );
                }
                final results = _controller.searchResults;
                if (_query.length < 2) {
                  return const _Message(
                    icon: LucideIcons.mapPin,
                    title: 'Find your area',
                    body: 'Type at least 2 characters to search.',
                  );
                }
                if (results.isEmpty) {
                  return _Message(
                    icon: LucideIcons.searchX,
                    title: 'No matches for "$_query"',
                    body:
                        'Try a nearby area or a shorter name - ESCOM lists '
                        'some neighbourhoods under a larger one.',
                  );
                }
                // Touched so the "Saved" markers update as locations change.
                _controller.savedLocations.length;
                return ListView.separated(
                  padding: listPadding,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    final saved = _isSaved(entry);
                    return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: saved ? null : () => _select(entry),
                          child: ShadCard(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.location,
                                        style: theme.textTheme.p.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.affectedAreas,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.muted,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (saved)
                                  const ShadBadge.secondary(
                                    child: Text('Saved'),
                                  )
                                else ...[
                                  ShadBadge.outline(
                                    child: Text(
                                      '${entry.groupCode} · ${entry.region}',
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    LucideIcons.chevronRight,
                                    size: 18,
                                    color: theme.colorScheme.mutedForeground,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .slideY(begin: 0.05, end: 0, duration: 200.ms);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred icon + title + body for the list area's non-result states
/// (prompt, no matches, failure).
class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Align(
      alignment: const Alignment(0, -0.5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: theme.colorScheme.mutedForeground),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.h4),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: theme.textTheme.muted),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// A [TextEditingController] created inline and disposed right after
/// `showDialog` resolves races the dialog's own exit animation, which keeps
/// rebuilding the field for a few more frames after the Future completes -
/// disposing it that early throws "used after being disposed". Owning the
/// controller in the dialog's own State ties its disposal to the dialog
/// element's actual teardown instead.
class _NicknameDialog extends StatefulWidget {
  final String locationName;

  const _NicknameDialog({required this.locationName});

  @override
  State<_NicknameDialog> createState() => _NicknameDialogState();
}

class _NicknameDialogState extends State<_NicknameDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.of(context).pop(_controller.text);

  @override
  Widget build(BuildContext context) {
    return ShadDialog(
      title: Text('Add ${widget.locationName}'),
      description: const Text(
        'That\'s ESCOM\'s own name for this location. Give it a nickname if '
        'you\'d rather see something else at a glance.',
      ),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ShadButton(onPressed: _save, child: const Text('Save')),
      ],
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ShadInput(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          placeholder: const Text('Nickname (optional) - e.g. Home, Office'),
          onSubmitted: (_) => _save(),
        ),
      ),
    );
  }
}
