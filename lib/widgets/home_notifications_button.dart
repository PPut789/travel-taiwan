import 'dart:async';

import 'package:flutter/material.dart';

import '../models/province_notification.dart';

class HomeNotificationsButton extends StatelessWidget {
  final Stream<List<ProvinceNotification>> notifications;
  final List<String> selectedProvinces;
  final Future<void> Function(List<String>)? onMarkRead;
  final Future<void> Function(ProvinceNotification)? onOpenNotification;

  const HomeNotificationsButton({
    super.key,
    required this.notifications,
    required this.selectedProvinces,
    this.onMarkRead,
    this.onOpenNotification,
  });

  List<ProvinceNotification> _visible(List<ProvinceNotification>? items) =>
      (items ?? [])
          .where((item) => selectedProvinces.contains(item.province))
          .toList();

  Future<void> _markRead(
    BuildContext context,
    List<ProvinceNotification> items,
  ) async {
    try {
      await onMarkRead?.call(
        items.where((item) => !item.isRead).map((item) => item.id).toList(),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark as read. Please try again.'),
        ),
      );
    }
  }

  Future<void> _openNotifications(
    BuildContext context,
    AsyncSnapshot<List<ProvinceNotification>> initial,
  ) async {
    unawaited(_markRead(context, _visible(initial.data)));
    final item = await showModalBottomSheet<ProvinceNotification>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF4FBFF),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .65,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Notifications',
                        style: TextStyle(
                          fontFamily: 'NotoSansThai',
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF19456B),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Videos and updates from your selected cities and counties',
                    style: TextStyle(
                      fontFamily: 'NotoSansThai',
                      fontSize: 14,
                      color: Color(0xFF557FA2),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<ProvinceNotification>>(
                    stream: notifications,
                    initialData: initial.data,
                    builder: (context, snapshot) {
                      final items = _visible(snapshot.data);
                      if (snapshot.hasError ||
                          (initial.hasError && !snapshot.hasData)) {
                        return const Center(
                          child: Text(
                            'Could not load notifications\nCheck your connection and try again',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansThai',
                              fontSize: 15,
                              color: Color(0xFF557FA2),
                            ),
                          ),
                        );
                      }
                      if (!snapshot.hasData &&
                          snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            selectedProvinces.isEmpty
                                ? 'Choose destinations to receive updates'
                                : 'No new updates in your selected destinations',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'NotoSansThai',
                              fontSize: 16,
                              color: Color(0xFF557FA2),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final date = item.createdAt.toLocal();
                          final time =
                              '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                          return Material(
                            color: item.isRead
                                ? Colors.white
                                : const Color(0xFFE2F2FF),
                            borderRadius: BorderRadius.circular(16),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFFDDF1FF),
                                child: Icon(
                                  item.isVideo
                                      ? Icons.video_library_outlined
                                      : Icons.edit_location_alt_outlined,
                                  color: const Color(0xFF3785BB),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF19456B),
                                ),
                              ),
                              subtitle: Text(
                                '${item.message}\n$time',
                                style: const TextStyle(
                                  fontFamily: 'NotoSansThai',
                                  fontSize: 13,
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                unawaited(_markRead(sheetContext, [item]));
                                Navigator.pop(sheetContext, item);
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (item != null && context.mounted) await onOpenNotification?.call(item);
  }

  @override
  Widget build(BuildContext context) =>
      StreamBuilder<List<ProvinceNotification>>(
        stream: notifications,
        builder: (context, snapshot) {
          final unread = _visible(snapshot.data).any((item) => !item.isRead);
          return IconButton(
            tooltip: unread ? 'Notifications: new updates' : 'Notifications',
            onPressed: () => _openNotifications(context, snapshot),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: .85),
              minimumSize: const Size(44, 44),
            ),
            icon: Badge(
              isLabelVisible: unread,
              child: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF19456B),
                size: 25,
              ),
            ),
          );
        },
      );
}
