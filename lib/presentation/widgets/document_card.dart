import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/document.dart';
import 'status_badge.dart';

enum DocumentViewMode { list, grid }

class DocumentCard extends StatelessWidget {
  final DocumentItem document;
  final DocumentViewMode mode;
  final VoidCallback onTap;
  final VoidCallback onMoreTap;

  const DocumentCard({
    super.key,
    required this.document,
    this.mode = DocumentViewMode.list,
    required this.onTap,
    required this.onMoreTap,
  });

  IconData _getFileIcon(String mimeOrExt) {
    if (mimeOrExt.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeOrExt.contains('xls') || mimeOrExt.contains('sheet')) return Icons.table_chart;
    if (mimeOrExt.contains('doc') || mimeOrExt.contains('word')) return Icons.description;
    if (mimeOrExt.contains('image')) return Icons.image;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String mimeOrExt) {
    if (mimeOrExt.contains('pdf')) return AppColors.accentCrimson;
    if (mimeOrExt.contains('xls') || mimeOrExt.contains('sheet')) return AppColors.accentEmerald;
    if (mimeOrExt.contains('doc') || mimeOrExt.contains('word')) return AppColors.primary;
    if (mimeOrExt.contains('image')) return AppColors.accentPurple;
    return AppColors.accentTeal;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileIcon = _getFileIcon(document.mimeType);
    final fileColor = _getFileColor(document.mimeType);

    if (mode == DocumentViewMode.grid) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: fileColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(fileIcon, color: fileColor, size: 24),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 18),
                      onPressed: onMoreTap,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  document.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  document.reference,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const Spacer(),
                const Divider(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge.fromRetention(document.retentionStatus),
                    Text(
                      '${document.fileSizeMB} MB',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    // List mode
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: fileColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(fileIcon, color: fileColor, size: 24),
        ),
        title: Text(
          document.title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(
              document.reference,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Text('• ${document.departmentName}', style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 8),
            Text('• v${document.version}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge.fromRetention(document.retentionStatus),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.more_vert, size: 20),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}
