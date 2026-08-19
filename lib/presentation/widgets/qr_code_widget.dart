import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.black12,
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: QrImageView(
        data: data.isEmpty ? 'FALE_ARCHIVES_EMPTY' : data,
        version: QrVersions.auto,
        size: size,
        gapless: false,
        backgroundColor: Colors.white,
        errorStateBuilder: (cxt, err) {
          return const Center(
            child: Text(
              'Erreur QR',
              style: TextStyle(fontSize: 10, color: Colors.red),
            ),
          );
        },
      ),
    );
  }
}
