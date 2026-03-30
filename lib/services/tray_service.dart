// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

/// Service for managing the system tray icon and menu.
///
/// Provides:
/// - System tray icon with tooltip
/// - Context menu (Show Window, Check for Updates, Quit)
/// - Click handlers for show/hide window
class TrayService {
  final SystemTray _systemTray = SystemTray();
  bool _initialized = false;

  /// Initialize the system tray.
  Future<void> initialize() async {
    if (_initialized) return;

    final iconPath =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';

    await _systemTray.initSystemTray(
      title: 'AgentSkills',
      iconPath: iconPath,
      toolTip: 'AgentSkills - AI Agent Skills Manager',
    );

    final menu = Menu();
    await menu.buildFrom([
      MenuItemLabel(
        label: 'Show Window',
        onClicked: (_) => _showWindow(),
      ),
      MenuItemLabel(
        label: 'Check for Updates',
        onClicked: (_) => _onCheckUpdates?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: 'Quit',
        onClicked: (_) => _quit(),
      ),
    ]);

    await _systemTray.setContextMenu(menu);

    _systemTray.registerSystemTrayEventHandler((eventName) {
      if (eventName == kSystemTrayEventClick) {
        Platform.isWindows
            ? _showWindow()
            : _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        Platform.isWindows
            ? _systemTray.popUpContextMenu()
            : _showWindow();
      }
    });

    _initialized = true;
  }

  VoidCallback? _onCheckUpdates;

  /// Set callback for when "Check for Updates" is clicked.
  void setOnCheckUpdates(VoidCallback callback) {
    _onCheckUpdates = callback;
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await _systemTray.destroy();
    await windowManager.destroy();
  }

  /// Update the tray tooltip text.
  Future<void> setTooltip(String tooltip) async {
    if (!_initialized) return;
    await _systemTray.setToolTip(tooltip);
  }

  /// Destroy the system tray.
  Future<void> destroy() async {
    if (!_initialized) return;
    await _systemTray.destroy();
    _initialized = false;
  }
}
