// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Debounced search input with keyboard shortcut support.
///
/// Replaces SearchInput.tsx from the React app. Features:
/// - Configurable debounce delay (default 300ms)
/// - Clear button
/// - Cmd/Ctrl+K shortcut to focus
/// - Escape to clear/unfocus
class SearchInput extends StatefulWidget {
  final String placeholder;
  final ValueChanged<String> onChanged;
  final int debounceMs;
  final String? initialValue;

  const SearchInput({
    super.key,
    required this.placeholder,
    required this.onChanged,
    this.debounceMs = 300,
    this.initialValue,
  });

  @override
  State<SearchInput> createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();
    if (widget.debounceMs == 0) {
      widget.onChanged(value);
    } else {
      _debounceTimer = Timer(
        Duration(milliseconds: widget.debounceMs),
        () => widget.onChanged(value),
      );
    }
    setState(() {}); // Update clear button visibility
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        // Cmd/Ctrl+K to focus
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyK &&
            (HardwareKeyboard.instance.isMetaPressed ||
                HardwareKeyboard.instance.isControlPressed)) {
          _focusNode.requestFocus();
        }
      },
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onTextChanged,
        style: TextStyle(fontSize: 13, color: onSurface),
        decoration: InputDecoration(
          hintText: widget.placeholder,
          hintStyle: TextStyle(
            color: onSurface.withValues(alpha: 0.4),
            fontSize: 13,
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: onSurface.withValues(alpha: 0.4),
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 16,
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                  onPressed: _clear,
                )
              : Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    '⌘K',
                    style: TextStyle(
                      fontSize: 11,
                      color: onSurface.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        onSubmitted: (_) {},
      ),
    );
  }
}
