// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'package:local_notifier/local_notifier.dart';

/// Service for sending native desktop notifications.
///
/// Wraps the local_notifier package to provide a simple API
/// for showing system-level notifications on macOS, Windows, and Linux.
class NotificationService {
  bool _initialized = false;

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
