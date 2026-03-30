// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';

/// Toast notification type.
enum ToastType { info, error }

/// A toast notification entry.
class ToastEntry {
  final String message;
  final ToastType type;
  final String id;

  ToastEntry({
    required this.message,
    this.type = ToastType.info,
  }) : id = DateTime.now().microsecondsSinceEpoch.toString();
}

/// Global toast manager that displays overlay notifications.
///
/// Replaces ToastProvider.tsx from the React app.
class ToastManager {
  static final ToastManager _instance = ToastManager._();
  factory ToastManager() => _instance;
  ToastManager._();

  final List<ToastEntry> _toasts = [];
  final _controller = StreamController<List<ToastEntry>>.broadcast();

  Stream<List<ToastEntry>> get stream => _controller.stream;
  List<ToastEntry> get toasts => List.unmodifiable(_toasts);

  void show(String message, {ToastType type = ToastType.info}) {
    final entry = ToastEntry(message: message, type: type);
    _toasts.add(entry);
    _controller.add(List.unmodifiable(_toasts));

    // Auto-dismiss after 4.5 seconds (matches original)
    Timer(const Duration(milliseconds: 4500), () {
      _toasts.removeWhere((t) => t.id == entry.id);
      _controller.add(List.unmodifiable(_toasts));
    });
  }

  void showError(String message) {
    show(message, type: ToastType.error);
  }
}

/// Widget that displays toast notifications as an overlay.
class ToastOverlay extends StatelessWidget {
  final Widget child;

  const ToastOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned(
          bottom: 16,
          right: 16,
          child: StreamBuilder<List<ToastEntry>>(
            stream: ToastManager().stream,
            initialData: const [],
            builder: (context, snapshot) {
              final toasts = snapshot.data ?? [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: toasts.map((toast) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ToastCard(entry: toast),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ToastCard extends StatelessWidget {
  final ToastEntry entry;

  const _ToastCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isError = entry.type == ToastType.error;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isError ? const Color(0xFFFEE2E2) : const Color(0xFFF0FDF4),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isError
                ? const Color(0xFFFCA5A5)
                : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              size: 18,
              color: isError
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF16A34A),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                entry.message,
                style: TextStyle(
                  fontSize: 13,
                  color: isError
                      ? const Color(0xFF991B1B)
                      : const Color(0xFF166534),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
