import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../controllers/location_controller.dart';
import '../data/saved_locations_store.dart';
import '../models/location_entry.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = Get.find<LocationController>();
  final _textController = ShadTextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _controller.search(value);
  }

  Future<void> _select(LocationEntry entry) async {
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => _NicknameDialog(locationName: entry.location),
    );
    if (nickname == null || !mounted) return;

    final result = await _controller.saveLocation(entry, customName: nickname);
    if (!mounted) return;
    switch (result) {
      case SaveResult.added:
        Get.back();
      case SaveResult.alreadySaved:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already saved')),
        );
      case SaveResult.limitReached:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can save up to 2 locations - remove one first',
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a location')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShadInput(
              controller: _textController,
              placeholder: const Text('Search your neighbourhood or area'),
              leading: const Icon(LucideIcons.search, size: 20),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              style: const TextStyle(fontSize: 16),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.info, size: 13),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Locations and groups follow ESCOM\'s own published '
                      'categorisation, not a general address lookup.',
                      style: ShadTheme.of(context).textTheme.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Obx(() {
                if (_controller.isSearching.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                final results = _controller.searchResults;
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      'Type at least 2 characters to search',
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    return ShadCard(
                          padding: const EdgeInsets.all(12),
                          child: InkWell(
                            onTap: () => _select(entry),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.location,
                                        style: ShadTheme.of(
                                          context,
                                        ).textTheme.p.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.affectedAreas,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: ShadTheme.of(
                                          context,
                                        ).textTheme.muted,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ShadBadge(
                                  child: Text(
                                    '${entry.groupCode} · ${entry.region}',
                                  ),
                                ),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.locationName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESCOM\'s own name for this location. Give it a nickname if '
            'you\'d rather see something else at a glance (optional).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nickname (optional)',
              hintText: 'e.g. Home, Office',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
