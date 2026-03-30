// Copyright 2024 AgentSkills Contributors
// SPDX-License-Identifier: MIT

import 'dart:ui';

import 'package:flutter/material.dart';

/// A glass morphism panel widget that provides the signature frosted-glass
/// look of the AgentSkills app.
///
/// Uses a custom BackdropFilter-based glassmorphism implementation that works
/// consistently across the supported desktop platforms.
///
/// This replaces the LiquidGlass.tsx React component.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final bool interactive;

  const GlassPanel({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.interactive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // This ClipRRect + BackdropFilter approach keeps the frosted-glass effect
    // consistent across all desktop platforms without relying on an optional
    // renderer package that is not needed by the current implementation.
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.white.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass-styled card with hover animation effect.
/// Enhances the GlassPanel with mouse-tracking highlight (desktop interaction).
class InteractiveGlassCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool selected;

  const InteractiveGlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = 16.0,
    this.padding,
    this.selected = false,
  });

  @override
  State<InteractiveGlassCard> createState() => _InteractiveGlassCardState();
}

class _InteractiveGlassCardState extends State<InteractiveGlassCard> {
  bool _isHovered = false;
  Offset _mousePosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      onHover: (event) {
        setState(() => _mousePosition = event.localPosition);
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: widget.selected
                ? primary.withValues(alpha: isDark ? 0.15 : 0.08)
                : _isHovered
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.02))
                    : Colors.transparent,
            border: Border.all(
              color: widget.selected
                  ? primary.withValues(alpha: 0.4)
                  : _isHovered
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06))
                      : Colors.transparent,
            ),
          ),
          padding: widget.padding ?? const EdgeInsets.all(12),
          child: widget.child,
        ),
      ),
    );
  }
}
