import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/user_service.dart';
import '../../state/auth_provider.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/stat_pill.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.user});
  final AppUser user;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _userService = UserService(ApiClient.instance);
  late final _nameController = TextEditingController(text: widget.user.name);
  late final _bioController = TextEditingController(text: widget.user.bio ?? '');
  late final _cityController = TextEditingController(text: widget.user.city ?? '');
  late String _level = widget.user.level;
  bool _saving = false;

  static const _levels = {
    'iniciante': 'Iniciante',
    'intermediario': 'Intermediario',
    'avancado': 'Avancado',
    'profissional': 'Profissional',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _userService.updateProfile(
        name: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        city: _cityController.text.trim(),
        level: _level,
      );
      if (mounted) await context.read<AuthProvider>().refreshCurrentUser();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nao foi possivel salvar')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(label: 'Nome', controller: _nameController, prefixIcon: Icons.person_outline),
              const SizedBox(height: 16),
              AppTextField(label: 'Cidade', controller: _cityController, prefixIcon: Icons.place_outlined),
              const SizedBox(height: 16),
              AppTextField(label: 'Bio', controller: _bioController, prefixIcon: Icons.edit_outlined),
              const SizedBox(height: 20),
              const Text('Nivel no tenis', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: _levels.entries
                    .map((e) => ChipTag(
                          label: e.value,
                          selected: _level == e.key,
                          onTap: () => setState(() => _level = e.key),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Salvar', onPressed: _save, isLoading: _saving),
            ],
          ),
        ),
      ),
    );
  }
}
