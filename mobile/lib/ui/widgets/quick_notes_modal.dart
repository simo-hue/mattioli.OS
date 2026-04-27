import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme.dart';
import '../../providers/notes_provider.dart';

class QuickNotesModal extends ConsumerStatefulWidget {
  const QuickNotesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickNotesModal(),
    );
  }

  @override
  ConsumerState<QuickNotesModal> createState() => _QuickNotesModalState();
}

class _QuickNotesModalState extends ConsumerState<QuickNotesModal> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (!_isInitialized) return;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    setState(() {
      _isSaving = true;
    });

    _debounce = Timer(const Duration(milliseconds: 800), () {
      ref.read(noteProvider.notifier).updateNote(_controller.text);
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<String>>(noteProvider, (previous, next) {
      if (!_isInitialized && next.hasValue) {
        _isInitialized = true;
        _controller.text = next.value!;
      }
    });

    final noteAsync = ref.watch(noteProvider);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side spacer / saving indicator
              SizedBox(
                width: 100,
                child: _isSaving 
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 12, 
                          height: 12, 
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mutedForeground)
                        ),
                        const SizedBox(width: 8),
                        Text('Salvataggio...', style: TextStyle(fontSize: 12, color: AppColors.mutedForeground.withValues(alpha: 0.8))),
                      ],
                    )
                  : const SizedBox(),
              ),
              const Text(
                'Note Veloci',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.foreground,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(
                width: 100,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: AppColors.mutedForeground, size: 20),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Main text area
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: noteAsync.isLoading && !_isInitialized
                ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
                : TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      height: 1.6,
                      color: AppColors.foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Scrivi qui le tue note...\n\nPuoi appuntare idee, pensieri o task veloci.',
                      hintStyle: TextStyle(
                        color: AppColors.mutedForeground.withValues(alpha: 0.5),
                        fontSize: 16,
                        height: 1.6,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
