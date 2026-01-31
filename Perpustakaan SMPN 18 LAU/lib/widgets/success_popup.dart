import 'package:flutter/material.dart';

/// Widget pop up sukses sederhana dengan animasi centang di tengah layar
class SuccessPopup {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    Duration duration = const Duration(seconds: 2),
  }) async {
    // Tampilkan dialog lalu jadwalkan penutupan otomatis agar future tidak menggantung
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => _SuccessPopupDialog(title: title, subtitle: subtitle),
    );

    await Future.delayed(duration);
    if (context.mounted &&
        Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _SuccessPopupDialog extends StatefulWidget {
  final String title;
  final String? subtitle;

  const _SuccessPopupDialog({required this.title, this.subtitle});

  @override
  State<_SuccessPopupDialog> createState() => _SuccessPopupDialogState();
}

class _SuccessPopupDialogState extends State<_SuccessPopupDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animasi ikon centang
                AnimatedBuilder(
                  animation: _checkAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.1),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 60 * _checkAnimation.value,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                // Subtitle (optional)
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
