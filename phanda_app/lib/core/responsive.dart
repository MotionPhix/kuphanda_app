import 'package:flutter/material.dart';

/// Layout breakpoints used across the app.
///
/// compact  — phones (bottom navigation)
/// medium   — small tablets / split-screen phones (navigation rail)
/// expanded — tablets and desktop (extended rail, multi-column content)
enum ScreenSize { compact, medium, expanded }

const double kCompactBreakpoint = 720;
const double kExpandedBreakpoint = 1100;
const double kContentMaxWidth = 1180;
const double kReadingMaxWidth = 760;

ScreenSize screenSizeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= kExpandedBreakpoint) return ScreenSize.expanded;
  if (width >= kCompactBreakpoint) return ScreenSize.medium;
  return ScreenSize.compact;
}

bool isCompact(BuildContext context) => screenSizeOf(context) == ScreenSize.compact;
bool isExpanded(BuildContext context) => screenSizeOf(context) == ScreenSize.expanded;

/// Horizontal page gutter for the current width.
double pageGutter(BuildContext context) {
  return switch (screenSizeOf(context)) {
    ScreenSize.compact => 16,
    ScreenSize.medium => 24,
    ScreenSize.expanded => 32,
  };
}

/// Centres content and applies the responsive page gutter.
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding,
    this.scrollable = false,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final gutter = pageGutter(context);
    final effectivePadding = padding ??
        EdgeInsets.fromLTRB(gutter, 8, gutter, gutter + 24);

    final content = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: effectivePadding, child: child),
    );

    if (scrollable) {
      return SingleChildScrollView(child: Center(child: content));
    }
    return Center(child: content);
  }
}

/// Two-pane layout that collapses to a single column below [breakpoint].
class ResponsiveTwoPane extends StatelessWidget {
  const ResponsiveTwoPane({
    super.key,
    required this.primary,
    required this.secondary,
    this.breakpoint = 1020,
    this.gap = 24,
    this.secondaryFlex = 4,
    this.primaryFlex = 7,
  });

  final Widget primary;
  final Widget secondary;
  final double breakpoint;
  final double gap;
  final int secondaryFlex;
  final int primaryFlex;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < breakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, SizedBox(height: gap), secondary],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: primaryFlex, child: primary),
        SizedBox(width: gap),
        Expanded(flex: secondaryFlex, child: secondary),
      ],
    );
  }
}

/// Consistent vertical rhythm between page sections.
class SectionGap extends StatelessWidget {
  const SectionGap({super.key, this.height = 28});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}
