import 'package:flutter/material.dart';

class PlaceFavoriteButton extends StatefulWidget {
  final bool selected;
  final Future<void> Function(bool)? onChanged;

  const PlaceFavoriteButton({
    super.key,
    required this.selected,
    this.onChanged,
  });

  @override
  State<PlaceFavoriteButton> createState() => _PlaceFavoriteButtonState();
}

class _PlaceFavoriteButtonState extends State<PlaceFavoriteButton> {
  bool _saving = false;

  Future<void> _toggle() async {
    if (_saving || widget.onChanged == null) return;
    setState(() => _saving = true);
    try {
      await widget.onChanged!(!widget.selected);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save favorite. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: widget.selected,
    child: IconButton(
      tooltip: widget.selected ? 'Remove from favorites' : 'Add to favorites',
      onPressed: _saving || widget.onChanged == null ? null : _toggle,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: .94),
        minimumSize: const Size(40, 40),
      ),
      icon: _saving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              widget.selected
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.selected
                  ? const Color(0xFFE86989)
                  : const Color(0xFF65829C),
              size: 23,
            ),
    ),
  );
}
