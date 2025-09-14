import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void showAddMealSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('Foto (IA)'),
            subtitle: const Text('Reconhecer alimentos pela câmera/galeria'),
            onTap: () { Navigator.pop(context); context.go('/nutrition/add?tab=photo'); },
          ),
          ListTile(
            leading: const Icon(Icons.qr_code_scanner),
            title: const Text('Scanner de código de barras'),
            subtitle: const Text('Buscar macros por EAN/GTIN'),
            onTap: () { Navigator.pop(context); context.go('/nutrition/scan'); },
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: const Text('Texto (IA/Manual)'),
            subtitle: const Text('Descreva a refeição ou informe manualmente'),
            onTap: () { Navigator.pop(context); context.go('/nutrition/add?tab=text'); },
          ),
        ],
      ),
    ),
  );
}
