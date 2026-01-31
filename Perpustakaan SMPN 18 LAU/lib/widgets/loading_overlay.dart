import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/global_loading_provider.dart';

class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GlobalLoading>(
      builder: (context, loading, child) {
        if (!loading.isLoading) return const SizedBox.shrink();
        return Stack(
          children: [
            // Block interactions
            const ModalBarrier(color: Colors.black54, dismissible: false),
            // Center spinner only (no message)
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        );
      },
    );
  }
}
