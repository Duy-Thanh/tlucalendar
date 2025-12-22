import 'package:flutter/material.dart';

/// Legacy banner that used to show foreground download progress.
/// The service has been removed, so this widget is now a placeholder.
class ForegroundDownloadBanner extends StatelessWidget {
  const ForegroundDownloadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
