import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'fish_sprite.dart';
import 'dive_page.dart';

final supabase = Supabase.instance.client;

class BiotaListPage extends StatefulWidget {
  const BiotaListPage({super.key});

  @override
  State<BiotaListPage> createState() => _BiotaListPageState();
}

class _BiotaListPageState extends State<BiotaListPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _kategori = [];

  bool _loading = true;
  String? _error;

  int? _selectedKategoriId;
  String _keyword = '';

  @override
  void initState() {
    super.initState();
    _init();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final text = _searchCtrl.text.trim();
      if (text == _keyword) return;
      setState(() => _keyword = text);
      _loadBiota();
    });
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([_loadKategori(), _loadBiota()]);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadKategori() async {
    final res = await supabase
        .from('kategori')
        .select('id,nama')
        .order('nama', ascending: true);

    _kategori = List<Map<String, dynamic>>.from(res);
    if (mounted) setState(() {});
  }

  Future<void> _loadBiota() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final builder = supabase
          .from('biota')
          .select(
            'id,nama,nama_latin,deskripsi,image_path,depth_meters,kategori_id,kategori(nama)',
          );

      dynamic q = builder;

      if (_selectedKategoriId != null) {
        q = q.eq('kategori_id', _selectedKategoriId);
      }

      if (_keyword.isNotEmpty) {
        q = q.or('nama.ilike.%$_keyword%,nama_latin.ilike.%$_keyword%');
      }

      final res = await q.order('depth_meters', ascending: true).limit(200);
      _items = List<Map<String, dynamic>>.from(res);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openDetail(Map<String, dynamic> biota) {
    final nama = (biota['nama'] ?? '-').toString();
    final latin = (biota['nama_latin'] ?? '').toString();
    final depth = biota['depth_meters']?.toString() ?? '0';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(nama),
        content: Text(
          '${latin.isNotEmpty ? "$latin\n\n" : ""}'
          'Kedalaman: $depth m\n\n'
          '${(biota["deskripsi"] ?? "").toString()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biota Laut'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadBiota,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: TextField(
                controller: _searchCtrl,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Cari biota (nama / latin)...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _keyword.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            FocusScope.of(context).unfocus();
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            // Filter kategori (chip)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: const Text('Semua'),
                      selected: _selectedKategoriId == null,
                      onSelected: (v) {
                        setState(() => _selectedKategoriId = null);
                        _loadBiota();
                      },
                    ),
                  ),
                  ..._kategori.map((k) {
                    final id = k['id'] as int;
                    final nama = (k['nama'] ?? '').toString();
                    final selected = _selectedKategoriId == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(nama),
                        selected: selected,
                        onSelected: (v) {
                          setState(() => _selectedKategoriId = v ? id : null);
                          _loadBiota();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(child: _buildBody()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DivePage()),
          );
        },
        icon: const Icon(Icons.waves),
        label: const Text('Dive'),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Error:\n$_error\n\n'
            'Cek: URL/key supabase benar, tabel ada, dan RLS policy SELECT aktif.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Data biota kosong.\nIsi dulu di Supabase (Table Editor / SQL).',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final b = _items[i];

        final nama = (b['nama'] ?? '-').toString();
        final latin = (b['nama_latin'] ?? '').toString();
        final depth = b['depth_meters']?.toString() ?? '0';
        final kategoriNama = (b['kategori']?['nama'] ?? '').toString();

        final path = b['image_path']?.toString().trim();
        final hasPath = path != null && path.isNotEmpty;

        return InkWell(
          onTap: () => _openDetail(b),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                // Thumbnail (FishSprite + fit)
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: SizedBox(
                    width: 92,
                    height: 92,
                    child: hasPath
                        ? Container(
                            color: Colors.black12,
                            padding: const EdgeInsets.all(6),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: FishSprite(
                                storagePath:
                                    path, // ✅ sudah pasti String non-null
                                width: 160,
                                height: 120,
                              ),
                            ),
                          )
                        : Container(
                            color: Colors.black12,
                            child: const Icon(Icons.image, size: 28),
                          ),
                  ),
                ),

                // Text
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (latin.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            latin,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.black.withOpacity(0.6),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _Pill(text: '${depth}m'),
                            const SizedBox(width: 8),
                            if (kategoriNama.isNotEmpty)
                              _Pill(text: kategoriNama),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
