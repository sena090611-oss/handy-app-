import 'package:material_ui/material_ui.dart';

import 'main.dart';

class AdminHomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final ApiService api;

  const AdminHomeScreen({
    super.key,
    required this.user,
    required this.api,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const _navy = Color(0xFF0F2147);
  static const _navyCard = Color(0xFF162C5B);
  static const _orange = Color(0xFFFF9D00);
  static const _blue = Color(0xFF2563EB);

  int _tabIndex = 0;
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _trabajadores = [];
  List<Map<String, dynamic>> _solicitudes = [];
  List<Map<String, dynamic>> _incidentes = [];
  List<Map<String, dynamic>> _municipios = [];
  List<Map<String, dynamic>> _zonas = [];
  List<Map<String, dynamic>> _portafolio = [];

  String _userFilter = 'todos';
  String _userSearch = '';
  int _opsSegment = 0; // 0: Solicitudes, 1: Incidentes
  int _catalogSegment = 0; // 0: Portafolio, 1: Zonas, 2: Municipios

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _safeGetList('/users'),
        _safeGetList('/trabajadores'),
        _safeGetList('/solicitudes'),
        _safeGetList('/reporte-incidente'),
        _safeGetList('/municipio'),
        _safeGetList('/zona'),
        _safeGetList('/portafolio'),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0];
        _trabajadores = results[1];
        _solicitudes = results[2];
        _incidentes = results[3];
        _municipios = results[4];
        _zonas = results[5];
        _portafolio = results[6];
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo conectar con el backend');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _safeGetList(String path) async {
    final data = await widget.api.getAuth(path);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
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

  Future<void> _updateUserStatus(int id, String status) async {
    try {
      await widget.api.patchAuth('/users/$id', {'isActive': status});
      _snack(
        status == 'activo'
            ? 'Usuario aprobado'
            : status == 'suspendido'
                ? 'Usuario suspendido'
                : 'Estado actualizado',
      );
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo actualizar el usuario');
    }
  }

  Future<void> _deleteUser(int id, String email) async {
    final ok = await _confirmDialog(
      title: 'Eliminar usuario',
      message: '¿Seguro que deseas eliminar a $email?',
    );
    if (!ok) return;
    try {
      await widget.api.deleteAuth('/users/$id');
      _snack('Usuario eliminado');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo eliminar el usuario');
    }
  }

  Future<void> _updateTrabajadorEstado(int id, String estado) async {
    try {
      await widget.api
          .patchAuth('/trabajadores/$id/estado', {'estado': estado});
      _snack('Estado del trabajador actualizado a $estado');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo actualizar el trabajador');
    }
  }

  Future<bool> _confirmDialog({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _showCreateMunicipioDialog() async {
    final ctrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo municipio'),
        content: TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del municipio',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (created != true || nombre.isEmpty) return;
    try {
      await widget.api.postAuth('/municipio', {'nombre': nombre});
      _snack('Municipio agregado');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo crear el municipio');
    }
  }

  Future<void> _showCreateZonaDialog() async {
    if (_municipios.isEmpty) {
      _snack('Primero carga o crea un municipio');
      return;
    }
    final ctrl = TextEditingController();
    int municipioId = _municipios.first['id'] as int;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Nueva zona / barrio'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la zona',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: municipioId,
                decoration: const InputDecoration(
                  labelText: 'Municipio',
                  border: OutlineInputBorder(),
                ),
                items: _municipios
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as int,
                        child: Text(m['nombre']?.toString() ?? ''),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setLocal(() => municipioId = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    final nombre = ctrl.text.trim();
    ctrl.dispose();
    if (created != true || nombre.isEmpty) return;
    try {
      await widget.api.postAuth('/zona', {
        'nombre': nombre,
        'municipioId': municipioId,
      });
      _snack('Zona agregada');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo crear la zona');
    }
  }

  Future<void> _showCreatePortafolioDialog() async {
    final oficioCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo oficio (Portafolio)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: oficioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del oficio',
                  hintText: 'Ej. Plomería',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: catCtrl,
                decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej. Mantenimiento del hogar',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    final oficio = oficioCtrl.text.trim();
    final categoria = catCtrl.text.trim();
    final desc = descCtrl.text.trim();
    oficioCtrl.dispose();
    catCtrl.dispose();
    descCtrl.dispose();
    if (created != true ||
        oficio.isEmpty ||
        categoria.isEmpty ||
        desc.isEmpty) {
      return;
    }
    final today = DateTime.now().toIso8601String().split('T').first;
    try {
      await widget.api.postAuth('/portafolio', {
        'nombreOficio': oficio,
        'categoria': categoria,
        'fechaHora': today,
        'estado': 'activo',
        'descripcion': desc,
      });
      _snack('Oficio agregado al portafolio');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo crear el oficio');
    }
  }

  Future<void> _deleteCatalogItem(String path, String label) async {
    final ok = await _confirmDialog(
      title: 'Eliminar $label',
      message: '¿Seguro que deseas eliminar este registro?',
    );
    if (!ok) return;
    try {
      await widget.api.deleteAuth(path);
      _snack('Eliminado correctamente');
      await _loadDashboard();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('No se pudo eliminar');
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminName = widget.user['fullName']?.toString() ??
        widget.user['nombre']?.toString() ??
        'Administrador';

    return Scaffold(
      backgroundColor: _navy,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panel Administrador',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              adminName,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _orange),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off,
                            color: _orange, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadDashboard,
                          style: FilledButton.styleFrom(
                            backgroundColor: _orange,
                            foregroundColor: _navy,
                          ),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadDashboard,
                  color: _orange,
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildHomeTab(),
                      _buildUsersTab(),
                      _buildOpsTab(),
                      _buildCatalogTab(),
                    ],
                  ),
                ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0B1938),
        indicatorColor: _orange.withValues(alpha: 0.25),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.dashboard, color: _orange),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline, color: Colors.white70),
            selectedIcon: Icon(Icons.people, color: _orange),
            label: 'Usuarios',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.assignment, color: _orange),
            label: 'Gestión',
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined, color: Colors.white70),
            selectedIcon: Icon(Icons.category, color: _orange),
            label: 'Catálogo',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    final pendientes =
        _users.where((u) => u['isActive'] == 'pendiente').toList();
    final trabajadoresPend =
        _trabajadores.where((t) => t['estado'] == 'PENDIENTE').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            _statCard(
              title: 'Pendientes',
              value: '${pendientes.length}',
              icon: Icons.hourglass_top,
              accent: _orange,
              onTap: () => setState(() {
                _userFilter = 'pendiente';
                _tabIndex = 1;
              }),
            ),
            _statCard(
              title: 'Usuarios',
              value: '${_users.length}',
              icon: Icons.people,
              accent: const Color(0xFF65A9FF),
              onTap: () => setState(() {
                _userFilter = 'todos';
                _tabIndex = 1;
              }),
            ),
            _statCard(
              title: 'Trabajadores',
              value: '${_trabajadores.length}',
              icon: Icons.build_circle,
              accent: const Color(0xFF34D399),
              onTap: () => setState(() {
                _userFilter = 'trabajadores';
                _tabIndex = 1;
              }),
            ),
            _statCard(
              title: 'Solicitudes / Inc.',
              value: '${_solicitudes.length} / ${_incidentes.length}',
              icon: Icons.assignment_turned_in,
              accent: const Color(0xFFF472B6),
              onTap: () => setState(() => _tabIndex = 2),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _sectionHeader(
          'Cuentas pendientes de aprobación',
          badge: '${pendientes.length}',
        ),
        const SizedBox(height: 10),
        if (pendientes.isEmpty)
          _emptyBox('No hay usuarios pendientes por aprobar.')
        else
          ...pendientes.map((u) => _userCard(u, compactActions: true)),
        if (trabajadoresPend.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionHeader(
            'Perfiles de trabajador pendientes',
            badge: '${trabajadoresPend.length}',
          ),
          const SizedBox(height: 10),
          ...trabajadoresPend.map(_trabajadorCard),
        ],
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_userFilter == 'trabajadores') {
      return Column(
        children: [
          _usersFilterBar(),
          Expanded(
            child: _trabajadores.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [_emptyBox('No hay trabajadores registrados.')],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trabajadores.length,
                    itemBuilder: (_, i) => _trabajadorCard(_trabajadores[i]),
                  ),
          ),
        ],
      );
    }

    final filtered = _users.where((u) {
      final matchesFilter =
          _userFilter == 'todos' || u['isActive'] == _userFilter;
      final q = _userSearch.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          (u['fullName']?.toString().toLowerCase().contains(q) ?? false) ||
          (u['email']?.toString().toLowerCase().contains(q) ?? false);
      return matchesFilter && matchesSearch;
    }).toList();

    return Column(
      children: [
        _usersFilterBar(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => _userSearch = v),
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o correo...',
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true,
              fillColor: _navyCard,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [_emptyBox('No hay usuarios con ese filtro.')],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _userCard(filtered[i]),
                ),
        ),
      ],
    );
  }

  Widget _usersFilterBar() {
    final filters = [
      ('todos', 'Todos'),
      ('pendiente', 'Pendientes'),
      ('activo', 'Activos'),
      ('suspendido', 'Suspendidos'),
      ('trabajadores', 'Trabajadores'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: filters.map((f) {
          final selected = _userFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f.$2),
              selected: selected,
              selectedColor: _orange,
              backgroundColor: _navyCard,
              labelStyle: TextStyle(
                color: selected ? _navy : Colors.white,
                fontWeight: FontWeight.bold,
              ),
              onSelected: (_) => setState(() => _userFilter = f.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOpsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _segmentButton(
                label: 'Solicitudes (${_solicitudes.length})',
                selected: _opsSegment == 0,
                onTap: () => setState(() => _opsSegment = 0),
              ),
              const SizedBox(width: 10),
              _segmentButton(
                label: 'Incidentes (${_incidentes.length})',
                selected: _opsSegment == 1,
                onTap: () => setState(() => _opsSegment = 1),
              ),
            ],
          ),
        ),
        Expanded(
          child: _opsSegment == 0
              ? _solicitudes.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_emptyBox('No hay solicitudes registradas.')],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _solicitudes.length,
                      itemBuilder: (_, i) =>
                          _solicitudCard(_solicitudes[i]),
                    )
              : _incidentes.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_emptyBox('No hay incidentes reportados.')],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _incidentes.length,
                      itemBuilder: (_, i) =>
                          _incidenteCard(_incidentes[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _segmentButton(
                label: 'Oficios (${_portafolio.length})',
                selected: _catalogSegment == 0,
                onTap: () => setState(() => _catalogSegment = 0),
              ),
              const SizedBox(width: 8),
              _segmentButton(
                label: 'Zonas (${_zonas.length})',
                selected: _catalogSegment == 1,
                onTap: () => setState(() => _catalogSegment = 1),
              ),
              const SizedBox(width: 8),
              _segmentButton(
                label: 'Municipios (${_municipios.length})',
                selected: _catalogSegment == 2,
                onTap: () => setState(() => _catalogSegment = 2),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _catalogSegment == 0
                  ? _showCreatePortafolioDialog
                  : _catalogSegment == 1
                      ? _showCreateZonaDialog
                      : _showCreateMunicipioDialog,
              style: FilledButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: _navy,
              ),
              icon: const Icon(Icons.add),
              label: Text(
                _catalogSegment == 0
                    ? 'Agregar oficio al portafolio'
                    : _catalogSegment == 1
                        ? 'Agregar zona'
                        : 'Agregar municipio',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        Expanded(
          child: _catalogSegment == 0
              ? _portafolioList()
              : _catalogSegment == 1
                  ? _zonasList()
                  : _municipiosList(),
        ),
      ],
    );
  }

  Widget _portafolioList() {
    if (_portafolio.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_emptyBox('No hay oficios en el portafolio.')],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _portafolio.length,
      itemBuilder: (_, i) {
        final item = _portafolio[i];
        return Card(
          color: _navyCard,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              item['nombreOficio']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item['categoria'] ?? ''} • ${item['descripcion'] ?? ''}',
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteCatalogItem(
                '/portafolio/${item['id']}',
                'oficio',
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _zonasList() {
    if (_zonas.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_emptyBox('No hay zonas registradas.')],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _zonas.length,
      itemBuilder: (_, i) {
        final item = _zonas[i];
        final mun = item['municipio'] is Map
            ? item['municipio']['nombre']?.toString() ?? ''
            : '';
        return Card(
          color: _navyCard,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(Icons.map_outlined, color: _orange),
            title: Text(
              item['nombre']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: mun.isEmpty
                ? null
                : Text(mun, style: const TextStyle(color: Colors.white70)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () =>
                  _deleteCatalogItem('/zona/${item['id']}', 'zona'),
            ),
          ),
        );
      },
    );
  }

  Widget _municipiosList() {
    if (_municipios.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_emptyBox('No hay municipios cargados.')],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _municipios.length,
      itemBuilder: (_, i) {
        final item = _municipios[i];
        return Card(
          color: _navyCard,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.location_on, color: _orange),
            title: Text(
              item['nombre']?.toString() ?? '',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600),
            ),
            trailing: Text(
              '#${item['id']}',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        );
      },
    );
  }

  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _navyCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: accent, size: 24),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, {String? badge}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (badge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: _orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _userCard(Map<String, dynamic> u, {bool compactActions = false}) {
    final id = u['id'] as int;
    final name = u['fullName']?.toString() ?? 'Sin nombre';
    final email = u['email']?.toString() ?? '';
    final role = u['role']?.toString() ?? '';
    final status = u['isActive']?.toString() ?? 'pendiente';
    final isSelf = id == widget.user['id'];

    final statusColor = switch (status) {
      'activo' => const Color(0xFF34D399),
      'pendiente' => _orange,
      _ => Colors.redAccent,
    };

    return Card(
      color: _navyCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _chip(role.toUpperCase(), _blue),
                const SizedBox(width: 6),
                _chip(status.toUpperCase(), statusColor),
              ],
            ),
            if (!isSelf) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  if (status != 'activo')
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _updateUserStatus(id, 'activo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text('Aprobar'),
                      ),
                    ),
                  if (status != 'activo' && status != 'suspendido')
                    const SizedBox(width: 8),
                  if (status != 'suspendido')
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _updateUserStatus(id, 'suspendido'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _orange,
                          side: const BorderSide(color: _orange),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        icon: const Icon(Icons.pause_circle_outline, size: 18),
                        label: const Text('Suspender'),
                      ),
                    ),
                  if (!compactActions) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Eliminar',
                      onPressed: () => _deleteUser(id, email),
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _trabajadorCard(Map<String, dynamic> t) {
    final id = t['id'] as int;
    final nombre = t['nombre']?.toString() ??
        t['user']?['fullName']?.toString() ??
        'Trabajador #$id';
    final estado = t['estado']?.toString() ?? 'PENDIENTE';
    final ocupacion = t['ocupacion']?.toString() ?? '';

    return Card(
      color: _navyCard,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                        nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (ocupacion.isNotEmpty)
                        Text(
                          ocupacion,
                          style: const TextStyle(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
                _chip(
                  estado,
                  estado == 'ACTIVO'
                      ? const Color(0xFF34D399)
                      : estado == 'PENDIENTE'
                          ? _orange
                          : Colors.redAccent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (estado != 'ACTIVO')
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _updateTrabajadorEstado(id, 'ACTIVO'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                      ),
                      child: const Text('Activar'),
                    ),
                  ),
                if (estado != 'ACTIVO' && estado != 'INACTIVO')
                  const SizedBox(width: 8),
                if (estado != 'INACTIVO')
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _updateTrabajadorEstado(id, 'INACTIVO'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _orange,
                        side: const BorderSide(color: _orange),
                      ),
                      child: const Text('Inactivar'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _solicitudCard(Map<String, dynamic> s) {
    final id = s['id'];
    final estado = s['estado']?.toString() ?? '';
    final desc = s['descripcion']?.toString() ?? 'Sin descripción';
    return Card(
      color: _navyCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          'Solicitud #$id',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: _chip(estado.toUpperCase(), _blue),
      ),
    );
  }

  Widget _incidenteCard(Map<String, dynamic> inc) {
    final id = inc['id'];
    final estado = inc['estado']?.toString() ?? '';
    final desc = inc['descripcion']?.toString() ??
        inc['motivo']?.toString() ??
        'Sin detalle';
    return Card(
      color: _navyCard,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.report_problem, color: _orange),
        title: Text(
          'Incidente #$id',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          desc,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: _chip(estado.toUpperCase(), _orange),
      ),
    );
  }

  Widget _segmentButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _orange : _navyCard,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? _navy : Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _emptyBox(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navyCard,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(color: Colors.white70),
      ),
    );
  }
}
