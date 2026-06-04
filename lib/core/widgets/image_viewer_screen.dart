import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/gen/app_localizations.dart';

/// Fullscreen pregled slike (dokaz garancije): zoom/pan + podeli.
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.imagePath, this.title});

  final String imagePath;
  final String? title;

  /// Otvori pregled; bezbedno (proveri da fajl postoji).
  static Future<void> open(
    BuildContext context, {
    required String imagePath,
    String? title,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    if (!File(imagePath).existsSync()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.imageMissing)));
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(imagePath: imagePath, title: title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final file = File(imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: title != null ? Text(title!) : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: l10n.imageShare,
            onPressed: () => _share(context),
          ),
        ],
      ),
      body: Center(
        child: file.existsSync()
            ? InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.file(file),
              )
            : Text(l10n.imageMissing,
                style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (!File(imagePath).existsSync()) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.imageMissing)));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(files: [XFile(imagePath)], text: title),
    );
  }
}
