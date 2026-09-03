import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/image_upload_service.dart';

class BusinessEditScreen extends StatefulWidget {
  const BusinessEditScreen({super.key, required this.editing});
  final bool editing;

  @override
  State<BusinessEditScreen> createState() => _BusinessEditScreenState();
}

class _BusinessEditScreenState extends State<BusinessEditScreen> {
  final name = TextEditingController();
  final username = TextEditingController();
  final category = TextEditingController();
  final city = TextEditingController();
  final state = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final website = TextEditingController();
  final instagram = TextEditingController();
  final description = TextEditingController();
  final institutionType = TextEditingController();

  String accountType = 'business';
  String? photoUrl;
  String? coverUrl;
  final galleryUrls = <String>[];
  bool loading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.editing) _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => loading = true);

    final doc = await FirebaseFirestore.instance
        .collection('business_profiles')
        .doc(uid)
        .get();
    final d = doc.data();
    if (d != null) {
      name.text = (d['name'] ?? '').toString();
      username.text = (d['username'] ?? '').toString();
      category.text = (d['category'] ?? '').toString();
      city.text = (d['city'] ?? '').toString();
      state.text = (d['state'] ?? '').toString();
      address.text = (d['address'] ?? '').toString();
      phone.text = (d['phone'] ?? '').toString();
      website.text = (d['websiteUrl'] ?? '').toString();
      instagram.text = (d['instagram'] ?? '').toString();
      description.text = (d['description'] ?? '').toString();
      institutionType.text = (d['institutionType'] ?? '').toString();
      accountType = (d['accountType'] ?? 'business').toString();
      photoUrl = d['photoUrl']?.toString();
      coverUrl = d['coverUrl']?.toString();
      if (d['galleryUrls'] is List) {
        galleryUrls
          ..clear()
          ..addAll((d['galleryUrls'] as List).map((e) => e.toString()));
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<String?> _image() async {
    try {
      final image = await ImageUploadService.instance.pickFromGallery(
        purpose: 'business',
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 84,
      );
      return image?.url;
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
      return null;
    }
  }

  Future<void> _save() async {
    if (name.text.trim().isEmpty ||
        username.text.trim().isEmpty ||
        category.text.trim().isEmpty ||
        city.text.trim().isEmpty ||
        state.text.trim().isEmpty ||
        address.text.trim().isEmpty) {
      context.snack(
          'Preencha nome, @usuário, categoria, cidade, estado e endereço.');
      return;
    }

    setState(() => saving = true);
    try {
      final points = await Geocoding().locationFromAddress(
        '${address.text.trim()}, ${city.text.trim()} - ${state.text.trim()}, Brasil',
      );
      if (points.isEmpty) throw Exception('Endereço não encontrado');

      final payload = <String, dynamic>{
        'name': name.text.trim(),
        'username': username.text.trim(),
        'category': category.text.trim(),
        'city': city.text.trim(),
        'state': state.text.trim(),
        'address': address.text.trim(),
        'latitude': points.first.latitude,
        'longitude': points.first.longitude,
        'phone': phone.text.trim(),
        'websiteUrl': website.text.trim(),
        'instagram': instagram.text.trim(),
        'description': description.text.trim(),
        'accountType': accountType,
        'institutionType': institutionType.text.trim(),
        'photoUrl': photoUrl,
        'coverUrl': coverUrl,
        'galleryUrls': galleryUrls,
      };

      if (widget.editing) {
        await ApiService.instance.updateBusiness(payload);
      } else {
        await ApiService.instance.createBusiness(payload);
      }

      if (!mounted) return;
      context.snack(
        widget.editing
            ? 'Perfil comercial atualizado.'
            : 'Perfil enviado para análise.',
      );
      context.go('/business');
    } on ApiException catch (e) {
      if (mounted) context.snack(e.message);
    } catch (_) {
      if (mounted) context.snack('Confira o endereço e tente novamente.');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      username,
      category,
      city,
      state,
      address,
      phone,
      website,
      instagram,
      description,
      institutionType,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: label),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.editing ? 'Editar comércio' : 'Criar comércio'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ImageBox(
                          url: photoUrl,
                          label: 'Avatar',
                          onTap: () async {
                            final url = await _image();
                            if (url != null && mounted)
                              setState(() => photoUrl = url);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ImageBox(
                          url: coverUrl,
                          label: 'Capa',
                          onTap: () async {
                            final url = await _image();
                            if (url != null && mounted)
                              setState(() => coverUrl = url);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  field(name, 'Nome público'),
                  field(username, '@usuário comercial'),
                  DropdownButtonFormField<String>(
                    initialValue: accountType,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de conta'),
                    items: const [
                      DropdownMenuItem(
                          value: 'business', child: Text('Comércio')),
                      DropdownMenuItem(
                          value: 'organizer', child: Text('Organizador')),
                      DropdownMenuItem(
                          value: 'institution', child: Text('Instituição')),
                    ],
                    onChanged: (v) =>
                        setState(() => accountType = v ?? 'business'),
                  ),
                  const SizedBox(height: 12),
                  if (accountType != 'business')
                    field(institutionType, 'Tipo de instituição/organizador'),
                  field(category, 'Categoria'),
                  field(city, 'Cidade'),
                  field(state, 'Estado (UF)'),
                  field(address, 'Endereço'),
                  field(phone, 'Telefone', keyboardType: TextInputType.phone),
                  field(website, 'Site'),
                  field(instagram, 'Instagram'),
                  field(description, 'Sobre', maxLines: 4),
                  const SizedBox(height: 8),
                  const Text(
                    'Galeria',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final url in galleryUrls)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              child: IconButton(
                                onPressed: () =>
                                    setState(() => galleryUrls.remove(url)),
                                icon: const Icon(Icons.cancel_rounded,
                                    color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      if (galleryUrls.length < 8)
                        InkWell(
                          onTap: () async {
                            final url = await _image();
                            if (url != null && mounted)
                              setState(() => galleryUrls.add(url));
                          },
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child:
                                const Icon(Icons.add_photo_alternate_rounded),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(
                      saving
                          ? 'Salvando...'
                          : widget.editing
                              ? 'Salvar alterações'
                              : 'Enviar para análise',
                    ),
                  ),
                ],
              ),
      );
}

class _ImageBox extends StatelessWidget {
  const _ImageBox(
      {required this.url, required this.label, required this.onTap});
  final String? url;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 120,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(16),
          ),
          child: (url ?? '').isEmpty
              ? Center(child: Text('Adicionar $label'))
              : Image.network(url!, fit: BoxFit.cover),
        ),
      );
}
