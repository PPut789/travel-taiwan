import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/interest_choices.dart';
import '../models/recommendation_preferences.dart';
import '../utils/app_routes.dart';
import '../widgets/selection_background.dart';
import 'interest_page.dart';

class DemographicsPage extends StatefulWidget {
  final List<String> selectedProvinces;
  final RecommendationPreferences? initialPreferences;
  final Future<InterestChoices> Function()? choicesLoader;

  const DemographicsPage({
    super.key,
    required this.selectedProvinces,
    this.initialPreferences,
    this.choicesLoader,
  });

  @override
  State<DemographicsPage> createState() => _DemographicsPageState();
}

class _DemographicsPageState extends State<DemographicsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageController;
  String? _gender;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(
      text: widget.initialPreferences?.age?.toString() ?? '',
    );
    final saved = widget.initialPreferences?.gender;
    if (RecommendationPreferences.genderOptions.contains(saved)) {
      _gender = saved;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_formKey.currentState!.validate()) return;
    final initial = widget.initialPreferences;
    Navigator.push(
      context,
      smoothRoute(
        InterestPage(
          selectedProvinces: widget.selectedProvinces,
          initialPreferences: RecommendationPreferences(
            provinces: widget.selectedProvinces,
            categories: initial?.categories ?? const [],
            types: initial?.types ?? const [],
            activities: initial?.activities ?? const [],
            age: int.parse(_ageController.text.trim()),
            gender: _gender,
          ),
          choicesLoader: widget.choicesLoader,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FAFF),
      appBar: AppBar(
        title: const Text('A little about you'),
        backgroundColor: const Color(0xFFE5F5FF),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: SelectionBackground()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          size: 64,
                          color: Color(0xFF3A6384),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Personalize your trip',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF19456B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tell us your gender and age, then choose what you enjoy.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF557FA2)),
                        ),
                        const SizedBox(height: 32),
                        DropdownButtonFormField<String>(
                          key: const ValueKey('gender-field'),
                          initialValue: _gender,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Gender',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: RecommendationPreferences.genderOptions
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => _gender = value),
                          validator: (value) => value == null
                              ? 'Please select your gender.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          key: const ValueKey('age-field'),
                          controller: _ageController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Age',
                            suffixText: 'years',
                            prefixIcon: Icon(Icons.cake_outlined),
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (value) {
                            final age = int.tryParse(value?.trim() ?? '');
                            return age == null || age <= 0
                                ? 'Please enter your age in whole years.'
                                : null;
                          },
                          onFieldSubmitted: (_) => _continue(),
                        ),
                        const SizedBox(height: 32),
                        FilledButton(
                          onPressed: _continue,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF76ADD1),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                          ),
                          child: const Text('Continue to interests'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
