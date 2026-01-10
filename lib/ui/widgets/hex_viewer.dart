import 'dart:typed_data';

import 'package:flutter/material.dart';

class HexViewer extends StatelessWidget {
  final Uint8List data;
  final int bytesPerRow;
  final Set<int>? highlightedBytes;
  final Color? highlightColor;

  const HexViewer({
    super.key,
    required this.data,
    this.bytesPerRow = 16,
    this.highlightedBytes,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Text('(empty)');
    }

    final rows = <Widget>[];
    for (int i = 0; i < data.length; i += bytesPerRow) {
      rows.add(_buildRow(context, i));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }

  Widget _buildRow(BuildContext context, int offset) {
    final hexParts = <Widget>[];
    final asciiParts = <Widget>[];

    for (int i = 0; i < bytesPerRow; i++) {
      final byteIndex = offset + i;

      if (byteIndex < data.length) {
        final byte = data[byteIndex];
        final isHighlighted = highlightedBytes?.contains(byteIndex) ?? false;

        hexParts.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: isHighlighted
                ? BoxDecoration(
                    color: highlightColor ?? Colors.yellow.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  )
                : null,
            child: Text(
              byte.toRadixString(16).padLeft(2, '0').toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isHighlighted
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : _getByteColor(byte, context),
              ),
            ),
          ),
        );

        // Add space after every 4 bytes for readability
        if ((i + 1) % 4 == 0 && i < bytesPerRow - 1) {
          hexParts.add(const SizedBox(width: 8));
        }

        // ASCII representation
        final char = (byte >= 32 && byte < 127) ? String.fromCharCode(byte) : '.';
        asciiParts.add(
          Container(
            decoration: isHighlighted
                ? BoxDecoration(
                    color: highlightColor ?? Colors.yellow.withAlpha(100),
                    borderRadius: BorderRadius.circular(2),
                  )
                : null,
            child: Text(
              char,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isHighlighted
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : (byte >= 32 && byte < 127)
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      } else {
        // Padding for incomplete rows
        hexParts.add(const SizedBox(width: 20));
        if ((i + 1) % 4 == 0 && i < bytesPerRow - 1) {
          hexParts.add(const SizedBox(width: 8));
        }
        asciiParts.add(const Text(' ', style: TextStyle(fontFamily: 'monospace', fontSize: 12)));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // Offset
          SizedBox(
            width: 48,
            child: Text(
              offset.toRadixString(16).padLeft(4, '0').toUpperCase(),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Hex bytes
          ...hexParts,
          const SizedBox(width: 16),
          // ASCII
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(children: asciiParts),
          ),
        ],
      ),
    );
  }

  Color _getByteColor(int byte, BuildContext context) {
    if (byte == 0) {
      return Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(100);
    }
    if (byte == 0xFF) {
      return Colors.red.shade300;
    }
    if (byte >= 32 && byte < 127) {
      return Colors.green.shade300;
    }
    return Theme.of(context).colorScheme.onSurface;
  }
}
