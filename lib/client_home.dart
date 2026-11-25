import 'package:material_ui/material_ui.dart';

import 'main.dart';

class ClientHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService api;

  const ClientHomeScreen({
    super.key,
    required this.user,
    required this.api,
  });

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  static const _navy = Color(0xFF0F2147);
  static const _navyDark = Color(0xFF0B1938);
  static const _navyCard = Color(0xFF162C5B);
  static const _orange = Color(0xFFFF9D00);
  static const _blue = Color(0xFF65A9FF);

  int _tabIndex = 0;
  bool _loading = true;
  String _searchQuery = '';
  String? _selectedOficio;
  int? _selectedMunicipioId;
  String _selectedMunicipioName = 'Montería';

  int _unreadCount = 0;
  List<Map<String, dynamic>> _municipios = [];
  List<Map<String, dynamic>> _oficios = [];
  List<Map<String, dynamic>> _solicitudes = [];
  List<Map<String, dynamic>> _trabajadores = [];

  static const _defaultOficios = [
    {'nombreOficio': 'Plomería'},
    {'nombreOficio': 'Electricidad'},
    {'nombreOficio': 'Carpintería'},
    {'nombreOficio': 'Cerrajería'},
    {'nombreOficio': 'Pintura'},
  ];

  @override
  void initState() {
    super.initState();
    _initMunicipioFromUser();
    _loadData();
  }

  void _initMunicipioFromUser() {
    final mun = widget.user['municipio'];
    if (mun is Map) {
      _selectedMunicipioId = mun['id'] as int?;
      _selectedMunicipioName = mun['nombre']?.toString() ?? 'Montería';
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _safeGet('/municipio'),
        _safeGet('/portafolio'),
        _safeGet('/solicitudes/mias'),
        _safeGet('/trabajadores/buscar'),
        _safeGet('/notificaciones/no-leidas/conteo'),
      ]);

      if (!mounted) return;
      final munList = _extractList(results[0]);
      final portList = _extractList(results[1]);
      final solList = _extractList(results[2]);
      final trabList = _extractList(results[3]);
      final notifData = results[4];

      int unread = 0;
      if (notifData is Map) {
        unread = (notifData['total'] ??
                notifData['count'] ??
                notifData['noLeidas'] ??
                0) as int? ??
            0;
      } else if (notifData is int) {
        unread = notifData;
      }

      setState(() {
        _municipios = munList;
        if (_selectedMunicipioId == null && munList.isNotEmpty) {
          _selectedMunicipioId = munList.first['id'] as int?;
          _selectedMunicipioName =
              munList.first['nombre']?.toString() ?? 'Montería';
        }
        _oficios = portList.isNotEmpty ? portList : _defaultOficios;
        _solicitudes = solList;
        _trabajadores = trabList;
        _unreadCount = unread;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<dynamic> _safeGet(String path) async {
    try {
      return await widget.api.getAuth(path);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _extractList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    if (raw is Map) {
      final inner = raw['data'] ?? raw['items'] ?? raw['trabajadores'];
      if (inner is List) {
        return inner
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }
    return [];
  }

  Future<void> _logout() async {
    await widget.api.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _emojiForOficio(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('plom')) return '🔧';
    if (lower.contains('electr')) return '⚡';
    if (lower.contains('carpint')) return '🪚';
    if (lower.contains('cerraj')) return '🔑';
    if (lower.contains('pint')) return '🎨';
    if (lower.contains('limp') || lower.contains('aseo')) return '🧹';
    if (lower.contains('jard')) return '🌿';
    return '🛠️';
  }

  Future<void> _pickMunicipio() async {
    if (_municipios.isEmpty) return;
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: _navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Selecciona tu municipio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ..._municipios.map(
            (m) => ListTile(
              leading: const Text('📍', style: TextStyle(fontSize: 18)),
              title: Text(
                m['nombre']?.toString() ?? '',
                style: const TextStyle(color: Colors.white),
              ),
              trailing: m['id'] == _selectedMunicipioId
                  ? const Icon(Icons.check, color: _orange)
                  : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedMunicipioId = picked['id'] as int?;
        _selectedMunicipioName = picked['nombre']?.toString() ?? 'Montería';
      });
    }
  }

  Future<void> _showNotifications() async {
    final raw = await _safeGet('/notificaciones');
    final items = _extractList(raw);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: _navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: items.isEmpty
            ? const Center(
                child: Text(
                  'No tienes notificaciones nuevas.',
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
              )
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final n = items[i];
                  return ListTile(
                    leading: const Text('🔔', style: TextStyle(fontSize: 20)),
                    title: Text(
                      n['titulo']?.toString() ?? 'Notificación',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      n['mensaje']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _showNewSolicitudDialog() async {
    final descCtrl = TextEditingController();
    final dirCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _navyCard,
        title: const Text(
          'Nueva solicitud',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: '¿Qué necesitas?',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Ej. Reparar fuga en el lavaplatos',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dirCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Dirección',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Ej. Calle 25 # 10-15',
                hintStyle: const TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _blue),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: Colors.white70)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: _navy,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    final desc = descCtrl.text.trim();
    final dir = dirCtrl.text.trim();
    descCtrl.dispose();
    dirCtrl.dispose();
    if (created != true || desc.isEmpty) return;

    try {
      await widget.api.postAuth('/solicitudes', {
        'descripcion': desc,
        if (dir.isNotEmpty) 'direccion': dir,
        if (_selectedMunicipioId != null) 'id_municipio': _selectedMunicipioId,
      });
      _snack('Solicitud creada correctamente');
      await _loadData();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo crear la solicitud');
    }
  }

  List<Map<String, dynamic>> get _filteredTrabajadores {
    return _trabajadores.where((t) {
      final q = _searchQuery.trim().toLowerCase();
      final nombre =
          (t['nombre'] ?? t['user']?['fullName'] ?? '').toString().toLowerCase();
      final ocup = (t['ocupacion'] ?? '').toString().toLowerCase();
      final matchQuery = q.isEmpty || nombre.contains(q) || ocup.contains(q);
      final matchOficio = _selectedOficio == null ||
          ocup.contains(_selectedOficio!.toLowerCase());
      return matchQuery && matchOficio;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _navy,
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildInicioTab(),
          _buildBuscarTab(),
          _buildSolicitudesTab(),
          _buildPerfilTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: _navyDark,
        indicatorColor: _orange.withValues(alpha: 0.22),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Text('🏠', style: TextStyle(fontSize: 18)),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Text('🔍', style: TextStyle(fontSize: 18)),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Text('📋', style: TextStyle(fontSize: 18)),
            label: 'Solicitudes',
          ),
          NavigationDestination(
            icon: Text('👤', style: TextStyle(fontSize: 18)),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  Widget _buildInicioTab() {
    final rawName = widget.user['fullName']?.toString() ??
        widget.user['nombre']?.toString() ??
        widget.user['email']?.toString().split('@').first ??
        'Usuario';
    final firstName = rawName.split(' ').first;
    final activeSols = _solicitudes
        .where((s) =>
            s['estado']?.toString().toLowerCase() != 'cancelada' &&
            s['estado']?.toString().toLowerCase() != 'completada')
        .toList();
    final filtered = _filteredTrabajadores;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: _orange,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Top Header matching the reference layout with Handy's dark-navy palette
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 16,
              20,
              22,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_navyDark, _navyCard],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, $firstName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _pickMunicipio,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x44243250),
                                border: Border.all(color: Colors.white30),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('📍',
                                      style: TextStyle(fontSize: 13)),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$_selectedMunicipioName, Córdoba',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white70,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bell button with unread badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _showNotifications,
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0x44E9EEF7),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white24),
                            ),
                            alignment: Alignment.center,
                            child: const Text('🔔',
                                style: TextStyle(fontSize: 20)),
                          ),
                        ),
                        if (_unreadCount > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: const BoxDecoration(
                                color: _orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$_unreadCount',
                                style: const TextStyle(
                                  color: _navy,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Search Bar Pill
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x55E9EEF7),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: Colors.white38),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: '¿Qué servicio necesitas hoy?',
                      hintStyle: const TextStyle(color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      prefixIcon: const SizedBox(
                        width: 44,
                        child: Center(
                          child: Text('🔍', style: TextStyle(fontSize: 18)),
                        ),
                      ),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => setState(() => _tabIndex = 1),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.tune,
                              color: _orange,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Oficios disponibles',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _oficios.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final name =
                          _oficios[i]['nombreOficio']?.toString() ?? 'Servicio';
                      final selected = _selectedOficio == name;
                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => setState(() {
                          _selectedOficio = selected ? null : name;
                        }),
                        child: Container(
                          width: 98,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? _orange.withValues(alpha: 0.22)
                                : _navyCard,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? _orange : Colors.white24,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _emojiForOficio(name),
                                style: const TextStyle(fontSize: 24),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: selected ? _orange : Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Active Solicitud Banner (glass card with left orange bar)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0x2EFF9D00),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _orange.withValues(alpha: 0.45)),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          decoration: const BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.horizontal(
                              left: Radius.circular(18),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeSols.isEmpty
                                            ? '¿Necesitas un servicio?'
                                            : 'Tienes ${activeSols.length} solicitud${activeSols.length == 1 ? '' : 'es'} en curso',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        activeSols.isEmpty
                                            ? 'Crea una solicitud rápida'
                                            : 'Estado: ${activeSols.first['estado'] ?? 'Pendiente'}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: _showNewSolicitudDialog,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _orange,
                                    foregroundColor: _navy,
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                  ),
                                  child: const Text(
                                    '+ Nueva solicitud',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Trabajadores recomendados
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Trabajadores recomendados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _tabIndex = 1),
                      child: const Text(
                        'Ver todos',
                        style: TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: CircularProgressIndicator(color: _orange),
                    ),
                  )
                else if (filtered.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: _navyCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'No hay trabajadores que coincidan con esos filtros.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  )
                else
                  ...filtered.take(5).map(_workerCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _workerCard(Map<String, dynamic> t) {
    final name = t['nombre']?.toString() ??
        t['user']?['fullName']?.toString() ??
        'Trabajador';
    final ocupacion = t['ocupacion']?.toString() ?? 'Servicios generales';
    final rating = t['calificacionPromedio']?.toString() ?? '5.0';
    return Card(
      color: _navyCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _orange.withValues(alpha: 0.2),
          child: Text(_emojiForOficio(ocupacion)),
        ),
        title: Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          ocupacion,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: _orange, size: 18),
            const SizedBox(width: 4),
            Text(
              rating,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuscarTab() {
    final list = _filteredTrabajadores;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Buscar trabajador u oficio...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: _navyCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const Center(
                    child: Text(
                      'No se encontraron trabajadores.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _workerCard(list[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudesTab() {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mis solicitudes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _showNewSolicitudDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: _navy,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _solicitudes.isEmpty
                ? const Center(
                    child: Text(
                      'Aún no tienes solicitudes.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _solicitudes.length,
                    itemBuilder: (_, i) {
                      final s = _solicitudes[i];
                      return Card(
                        color: _navyCard,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text(
                            s['descripcion']?.toString() ?? 'Solicitud',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            'Estado: ${s['estado'] ?? 'Pendiente'}',
                            style: const TextStyle(color: _orange),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilTab() {
    final name = widget.user['fullName']?.toString() ??
        widget.user['nombre']?.toString() ??
        'Usuario';
    final email = widget.user['email']?.toString() ?? '';
    return SafeArea(
      child: Center(
        child: Card(
          color: _navyCard,
          margin: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: _orange.withValues(alpha: 0.2),
                  child: const Text('👤', style: TextStyle(fontSize: 34)),
                ),
                const SizedBox(height: 16),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(email, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Chip(
                  backgroundColor: _orange,
                  label: Text(
                    (widget.user['role'] ?? 'cliente')
                        .toString()
                        .toUpperCase(),
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _orange,
                      side: const BorderSide(color: _orange),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
