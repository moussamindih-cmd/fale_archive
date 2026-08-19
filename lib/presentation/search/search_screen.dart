import 'package:flutter/material.dart';
import '../../core/routing/app_router.dart';
import '../app_state.dart';
import '../widgets/document_card.dart';
import '../widgets/app_button.dart';

class SearchScreen extends StatefulWidget {
  final AppStateProvider appState;

  const SearchScreen({super.key, required this.appState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final docs = widget.appState.filteredDocuments;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recherche Avancée d Archives',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            'Recherchez par mots-clés, référence, métadonnées ou contenu plein texte (OCR).',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
          const SizedBox(height: 20),

          // Multi-Criteria Form Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryCtrl,
                          onChanged: widget.appState.setSearchQuery,
                          decoration: const InputDecoration(
                            hintText: 'Rechercher par titre, résumé ou mot-clé...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      AppButton(
                        label: 'Rechercher',
                        icon: Icons.search,
                        onPressed: () {
                          widget.appState.setSearchQuery(_queryCtrl.text);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _refCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Référence exacte (ex: FAC-2026)',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _tagCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Mots-clés indexés',
                            prefixIcon: Icon(Icons.tag_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Résultats de la recherche (${docs.length} documents)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return DocumentCard(
                  document: doc,
                  mode: DocumentViewMode.list,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      AppRoutes.documentDetails,
                      arguments: doc,
                    );
                  },
                  onMoreTap: () {},
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
