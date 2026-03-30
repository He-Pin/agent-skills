// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:local_notifier/local_notifier.dart';

/// Service for sending native desktop notifications.
///
/// Wraps the local_notifier package to provide a simple API
/// for showing system-level notifications on macOS, Windows, and Linux.
class NotificationService {
  bool _initialized = false;

  /// Active notifications are retained here to prevent garbage collection
  /// before the user has a chance to interact with them (e.g., click).
  final List<LocalNotification> _activeNotifications = [];

  /// Initialize the notification service.
  Future<void> initialize() async {
    if (_initialized) return;
    await localNotifier.setup(
      appName: 'AgentSkills',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    _initialized = true;
  }

  /// Show a notification with a title and body.
  Future<void> show({
    required String title,
    required String body,
    void Function()? onClick,
  }) async {
    if (!_initialized) await initialize();

    final notification = LocalNotification(
      title: title,
      body: body,
    );

    if (onClick != null) {
      notification.onClick = onClick;
    }

    // Retain the notification to prevent GC before user interaction.
    // Clean up closed notifications on each new show to avoid unbounded growth.
    _activeNotifications.removeWhere((n) => n.identifier == null);
    _activeNotifications.add(notification);

    notification.onClose = (_) {
      _activeNotifications.remove(notification);
    };

    await notification.show();
  }

  /// Show an update available notification.
  Future<void> showUpdateAvailable({
    required String version,
    void Function()? onClick,
  }) async {
    await show(
      title: 'Update Available',
      body: 'AgentSkills v$version is available. Click to download.',
      onClick: onClick,
    );
  }
}
