import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/job_offer.dart';
import '../../state/job_offers_state.dart';
import '../../theme/app_theme.dart';

/// Création et modification d'une offre (§5.2.1).
///
/// Une offre créée ici démarre toujours en brouillon : la publication passe
/// obligatoirement par le circuit de validation.
class JobOfferFormScreen extends StatefulWidget {
  final JobOffersState offersState;
  final JobOffer? existing;

  const JobOfferFormScreen({
    super.key,
    required this.offersState,
    this.existing,
  });

  @override
  State<JobOfferFormScreen> createState() => _JobOfferFormScreenState();
}

class _JobOfferFormScreenState extends State<JobOfferFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _requirementsCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _positionsCtrl;
  late final TextEditingController _salaryMinCtrl;
  late final TextEditingController _salaryMaxCtrl;
  final _skillCtrl = TextEditingController();

  late ContractType _contractType;
  late bool _salaryVisible;
  late List<String> _skills;
  DateTime? _deadline;
  bool _saveAsTemplate = false;
  bool _isSaving = false;

  static final _dateFormat = DateFormat('dd/MM/yyyy');

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final o = widget.existing;
    _titleCtrl = TextEditingController(text: o?.title ?? '');
    _descriptionCtrl = TextEditingController(text: o?.description ?? '');
    _requirementsCtrl = TextEditingController(text: o?.requirements ?? '');
    _locationCtrl = TextEditingController(text: o?.location ?? '');
    _positionsCtrl =
        TextEditingController(text: (o?.positionsCount ?? 1).toString());
    _salaryMinCtrl =
        TextEditingController(text: o?.salaryMin?.round().toString() ?? '');
    _salaryMaxCtrl =
        TextEditingController(text: o?.salaryMax?.round().toString() ?? '');
    _contractType = o?.contractType ?? ContractType.cdi;
    _salaryVisible = o?.salaryVisible ?? false;
    _skills = List.of(o?.skills ?? const []);
    _deadline = o?.deadline;
  }

  @override
  void dispose() {
    for (final c in [
      _titleCtrl,
      _descriptionCtrl,
      _requirementsCtrl,
      _locationCtrl,
      _positionsCtrl,
      _salaryMinCtrl,
      _salaryMaxCtrl,
      _skillCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSkill([String? raw]) {
    final value = (raw ?? _skillCtrl.text).trim();
    if (value.isEmpty || _skills.contains(value)) {
      _skillCtrl.clear();
      return;
    }
    setState(() {
      _skills.add(value);
      _skillCtrl.clear();
    });
  }

  double? _parseAmount(TextEditingController ctrl) {
    final raw = ctrl.text.replaceAll(RegExp(r'\s'), '');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final min = _parseAmount(_salaryMinCtrl);
    final max = _parseAmount(_salaryMaxCtrl);
    // Contrôle aussi posé en base ; le faire ici évite un aller-retour et
    // un message d'erreur technique.
    if (min != null && max != null && max < min) {
      _snack('Le salaire maximum doit être supérieur au minimum.', kDanger);
      return;
    }

    setState(() => _isSaving = true);

    final offer = JobOffer(
      id: widget.existing?.id ?? '',
      organizationId: widget.existing?.organizationId ?? '',
      reference: widget.existing?.reference ?? '',
      title: _titleCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      requirements: _requirementsCtrl.text.trim().isEmpty
          ? null
          : _requirementsCtrl.text.trim(),
      skills: _skills,
      contractType: _contractType,
      location:
          _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      positionsCount: int.tryParse(_positionsCtrl.text.trim()) ?? 1,
      salaryMin: min,
      salaryMax: max,
      salaryVisible: _salaryVisible,
      deadline: _deadline,
      templateName: _saveAsTemplate ? _titleCtrl.text.trim() : null,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final error = _isEditing
        ? await widget.offersState.update(widget.existing!.id, offer)
        : await widget.offersState.create(offer, asTemplate: _saveAsTemplate);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error != null) {
      _snack(error, kDanger);
      return;
    }
    Navigator.pop(context);
    _snack(
      _isEditing
          ? 'Offre mise à jour.'
          : _saveAsTemplate
              ? 'Modèle enregistré.'
              : 'Offre créée en brouillon.',
      null,
    );
  }

  void _snack(String message, Color? color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kDarkBackground : kBackground,
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier l\'offre' : 'Nouvelle offre'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Intitulé du poste *',
                hintText: 'Ex : Comptable senior',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Intitulé requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Description du poste *',
                alignLabelWithHint: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Description requise' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _requirementsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Profil recherché',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            _skillsField(isDark),
            const SizedBox(height: 16),
            DropdownButtonFormField<ContractType>(
              initialValue: _contractType,
              decoration: const InputDecoration(labelText: 'Type de contrat'),
              items: [
                for (final t in ContractType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (v) => setState(() => _contractType = v!),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _locationCtrl,
                    decoration: const InputDecoration(labelText: 'Lieu'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextFormField(
                    controller: _positionsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Postes'),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      return (n == null || n < 1) ? '≥ 1' : null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salaryMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Salaire min (XAF)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salaryMaxCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Salaire max (XAF)'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _salaryVisible,
              onChanged: (v) => setState(() => _salaryVisible = v),
              title: const Text('Afficher le salaire aux candidats'),
              subtitle: const Text(
                'Sans cela, la fourchette reste interne et n\'apparaît pas '
                'sur la page publique.',
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Date limite de candidature'),
              subtitle: Text(
                _deadline == null
                    ? 'Aucune — l\'offre reste ouverte'
                    : _dateFormat.format(_deadline!),
              ),
              trailing: _deadline == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _deadline = null),
                    ),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _deadline ?? now.add(const Duration(days: 30)),
                  firstDate: now,
                  lastDate: DateTime(now.year + 3),
                  locale: const Locale('fr', 'FR'),
                );
                if (picked != null) setState(() => _deadline = picked);
              },
            ),
            if (!_isEditing) ...[
              const Divider(height: 32),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _saveAsTemplate,
                onChanged: (v) => setState(() => _saveAsTemplate = v),
                title: const Text('Enregistrer comme modèle réutilisable'),
                subtitle: const Text(
                  'Un modèle ne se publie pas : il sert de point de départ '
                  'à de nouvelles offres.',
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isEditing ? 'Enregistrer' : 'Créer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skillsField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _skillCtrl,
          decoration: InputDecoration(
            labelText: 'Compétences requises',
            hintText: 'Saisir puis valider',
            suffixIcon: IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: _addSkill,
            ),
          ),
          onFieldSubmitted: _addSkill,
        ),
        if (_skills.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _skills)
                Chip(
                  label: Text(s),
                  onDeleted: () => setState(() => _skills.remove(s)),
                  deleteIcon: const Icon(Icons.close_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
