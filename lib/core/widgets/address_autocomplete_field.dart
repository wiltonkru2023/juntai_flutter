import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../services/address_search_service.dart';

class AddressAutocompleteField extends StatefulWidget {
  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.onSelected,
    this.onChanged,
    this.enabled = true,
    this.label = 'Local',
    this.hint = 'Digite rua, número, bairro ou local',
  });

  final TextEditingController controller;
  final ValueChanged<AddressSuggestion> onSelected;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final String label;
  final String hint;

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _loading = false;
  bool _choosing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (!_focusNode.hasFocus && !_choosing) {
      Future<void>.delayed(
        const Duration(milliseconds: 160),
        () {
          if (mounted && !_focusNode.hasFocus && !_choosing) {
            setState(() {
              _suggestions = const [];
            });
          }
        },
      );
    }
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();

    final query = value.trim();

    if (query.length < 3) {
      setState(() {
        _loading = false;
        _error = null;
        _suggestions = const [];
      });
      return;
    }

    _debounce = Timer(
      const Duration(milliseconds: 700),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await AddressSearchService.instance.search(query);

      if (!mounted) return;

      if (widget.controller.text.trim() != query) {
        return;
      }

      setState(() {
        _suggestions = result;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Não foi possível buscar endereços agora.';
        _suggestions = const [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _select(AddressSuggestion suggestion) {
    _choosing = true;

    widget.controller
      ..text = suggestion.label
      ..selection = TextSelection.collapsed(
        offset: suggestion.label.length,
      );

    widget.onSelected(suggestion);

    setState(() {
      _suggestions = const [];
      _error = null;
    });

    _focusNode.unfocus();
    _choosing = false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          textCapitalization: TextCapitalization.words,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
            ),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : widget.controller.text.isNotEmpty
                    ? IconButton(
                        onPressed: widget.enabled
                            ? () {
                                widget.controller.clear();
                                widget.onChanged?.call('');
                                setState(() {
                                  _suggestions = const [];
                                  _error = null;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.close_rounded),
                      )
                    : null,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              _error!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
              ),
            ),
          ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];

                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.place_outlined,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    suggestion.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
