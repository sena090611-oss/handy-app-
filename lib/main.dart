import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const HandyApp());
}

class ApiService {
  static const baseUrl = 'http://10.3.83.188:3000';
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
    }
    await _storage.deleteAll();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    required int municipioId,
    required String role,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'nombre': nombre,
        'fullName': nombre,
        'id_municipio': municipioId,
        'role': role,
      }),
    );
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> municipios() async {
    final response = await http.get(Uri.parse('$baseUrl/municipio'));
    if (response.statusCode >= 400) {
      throw ApiException('No se pudieron cargar los municipios');
    }
    final decoded = jsonDecode(response.body);
    return (decoded as List)
        .map((item) => (item as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> profile() async {
    final accessToken = await _storage.read(key: 'access_token');
    final response = await http.get(
      Uri.parse('$baseUrl/auth/profile'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(body['message']?.toString() ?? 'Error del servidor');
    }
    return body;
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class HandyApp extends StatelessWidget {
  const HandyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Handy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _api = ApiService();
  final _storage = const FlutterSecureStorage();
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final _emailController = TextController();
  final _passwordController = TextController();
  final _nameController = TextController();
  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePassword = true;
  String _role = 'cliente';
  int? _municipioId;
  List<Map<String, dynamic>> _municipios = [];

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final token = await _storage.read(key: 'access_token');
    if (token != null && mounted) {
      await _openProfile();
    }
  }

  Future<void> _openProfile() async {
    setState(() => _loading = true);
    try {
      final result = await _api.profile();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(
            user: result['user'] as Map<String, dynamic>,
            api: _api,
          ),
        ),
      );
    } on ApiException catch (_) {
      await _storage.deleteAll();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMunicipios() async {
    if (_municipios.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      _municipios = await _api.municipios();
      if (_municipios.isNotEmpty) _municipioId = _municipios.first['id'] as int;
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await _api.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      await _api.saveTokens(
        result['token'] as String,
        result['refreshToken'] as String,
      );
      await _openProfile();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (!_registerForm.currentState!.validate()) return;
    if (_municipioId == null) {
      _showMessage('Selecciona un municipio');
      return;
    }
    setState(() => _loading = true);
    try {
      final result = await _api.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nombre: _nameController.text.trim(),
        municipioId: _municipioId!,
        role: _role,
      );
      _showMessage(result['message']?.toString() ?? 'Registro enviado');
      setState(() {
        _isLogin = true;
        _passwordController.clear();
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.handshake_outlined,
                    size: 72,
                    color: Color(0xFF2563EB),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Handy',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Iniciar sesión')),
                      ButtonSegment(value: false, label: Text('Registrarse')),
                    ],
                    selected: {_isLogin},
                    onSelectionChanged: (value) async {
                      setState(() => _isLogin = value.first);
                      if (!_isLogin) await _loadMunicipios();
                    },
                  ),
                  const SizedBox(height: 20),
                  if (_isLogin) _loginFormWidget() else _registerFormWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _loginFormWidget() {
    return Form(
      key: _loginForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _login,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ingresar'),
          ),
        ],
      ),
    );
  }

  Widget _registerFormWidget() {
    return Form(
      key: _registerForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre completo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ingresa tu nombre'
                : null,
          ),
          const SizedBox(height: 12),
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _municipioId,
            decoration: const InputDecoration(
              labelText: 'Municipio',
              border: OutlineInputBorder(),
            ),
            items: _municipios
                .map(
                  (municipio) => DropdownMenuItem(
                    value: municipio['id'] as int,
                    child: Text(municipio['nombre'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _municipioId = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Tipo de cuenta',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'cliente', child: Text('Cliente')),
              DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),
            ],
            onChanged: (value) => setState(() => _role = value ?? 'cliente'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Correo electrónico',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
        if (!value.contains('@')) return 'Ingresa un correo válido';
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa tu contraseña';
        if (!_isLogin &&
            (value.length < 8 ||
                !RegExp(r'[A-Za-z]').hasMatch(value) ||
                !RegExp(r'[0-9]').hasMatch(value))) {
          return 'Debe tener 8 caracteres, una letra y un número';
        }
        return null;
      },
    );
  }
}

class TextController extends TextEditingController {}

class ProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;
  final ApiService api;

  const ProfileScreen({super.key, required this.user, required this.api});

  Future<void> _logout(BuildContext context) async {
    await api.logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircleAvatar(
                  radius: 36,
                  child: Icon(Icons.person, size: 40),
                ),
                const SizedBox(height: 16),
                Text(
                  user['fullName']?.toString() ??
                      user['nombre']?.toString() ??
                      'Usuario',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(user['email']?.toString() ?? ''),
                const SizedBox(height: 8),
                Chip(label: Text(user['role']?.toString() ?? '')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
