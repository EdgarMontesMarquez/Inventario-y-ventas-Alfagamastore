import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/design_system/tokens/color_tokens.dart';
import '../../../core/design_system/widgets/custom_inputs.dart';
import '../../../shared/providers/repository_providers.dart';
import '../../../shared/widgets/credit_card.dart';
import '../../../shared/widgets/empty_state.dart';

class FinalizedCreditsScreen extends ConsumerStatefulWidget {
  const FinalizedCreditsScreen({super.key});

  @override
  ConsumerState<FinalizedCreditsScreen> createState() => _FinalizedCreditsScreenState();
}

class _FinalizedCreditsScreenState extends ConsumerState<FinalizedCreditsScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final creditsAsync = ref.watch(creditsFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Créditos Finalizados'),
      ),
      body: creditsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error al cargar créditos: $err')),
        data: (credits) {
          final finalizedCredits = credits.where((c) => c.status == 'finalizado').toList();

          final filtered = finalizedCredits.where((c) {
            final s = _searchQuery.trim().toLowerCase();
            final nameMatch = c.clientName.toLowerCase().contains(s);
            final docMatch = c.generalNotes.toLowerCase().contains(s);
            return nameMatch || docMatch;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: CustomTextField(
                  label: '',
                  hint: 'Buscar cliente por nombre o documento…',
                  prefixIcon: const Icon(Icons.search, size: 20, color: ColorTokens.textMuted),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: finalizedCredits.isEmpty
                    ? const EmptyState(
                        title: 'Sin créditos finalizados',
                        description: 'Aquí se mostrarán los clientes que ya pagaron todo su saldo.',
                        icon: Icons.history,
                      )
                    : filtered.isEmpty
                        ? const EmptyState(
                            title: 'Sin resultados',
                            description: 'No se encontraron clientes finalizados con ese criterio.',
                            icon: Icons.search_off,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (context, idx) => const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final credit = filtered[idx];
                              return CreditCard(
                                credit: credit,
                                onTap: () {
                                  context.push('/credits/${credit.id}');
                                },
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
