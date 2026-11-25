import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'admin_home.dart';
import 'client_home.dart';

void main() {
  runApp(const HandyApp());
}

class ApiService {
  static const baseUrl = 'http://10.3.83.188:3001';
  static const _timeout = Duration(seconds: 8);
  final _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: 'access_token', value: accessToken);
    await _storage.write(key: 'refresh_token', value: refreshToken);
  }

  Future<void> logout() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken != null) {
      await http
          .post(
            Uri.parse('$baseUrl/auth/logout'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refreshToken}),
          )
          .timeout(_timeout);
    }
    await _storage.deleteAll();
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String nombre,
    required int municipioId,
    required String role,
  }) async {
    final response = await http
        .post(
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
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> municipios() async {
    final response =
        await http.get(Uri.parse('$baseUrl/municipio')).timeout(_timeout);
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
    final response = await http
        .get(
          Uri.parse('$baseUrl/auth/profile'),
          headers: {
            'Authorization': 'Bearer $accessToken',
            'Content-Type': 'application/json',
          },
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<Map<String, String>> _authHeaders() async {
    final accessToken = await _storage.read(key: 'access_token');
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  Future<dynamic> getAuth(String path) async {
    final response = await http
        .get(Uri.parse('$baseUrl$path'), headers: await _authHeaders())
        .timeout(_timeout);
    return _decodeAny(response);
  }

  Future<dynamic> postAuth(String path, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeAny(response);
  }

  Future<dynamic> patchAuth(String path, Map<String, dynamic> body) async {
    final response = await http
        .patch(
          Uri.parse('$baseUrl$path'),
          headers: await _authHeaders(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _decodeAny(response);
  }

  Future<void> deleteAuth(String path) async {
    final response = await http
        .delete(Uri.parse('$baseUrl$path'), headers: await _authHeaders())
        .timeout(_timeout);
    _decodeAny(response);
  }

  dynamic _decodeAny(http.Response response) {
    final decoded =
        response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      final msg = decoded is Map
          ? decoded['message']?.toString() ?? 'Error del servidor'
          : 'Error del servidor';
      throw ApiException(msg);
    }
    return decoded;
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
  final _loginEmailController = TextController();
  final _loginPasswordController = TextController();
  final _registerEmailController = TextController();
  final _registerPasswordController = TextController();
  final _nameController = TextController();
  bool _isLogin = true;
  bool _loading = false;
  bool _loadingMunicipios = false;
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
      await _openProfile(showSpinner: false);
    }
  }

  Future<void> _openProfile({bool showSpinner = true}) async {
    if (showSpinner) setState(() => _loading = true);
    try {
      final result = await _api.profile();
      if (!mounted) return;
      final user = result['user'] as Map<String, dynamic>;
      final role = user['role']?.toString();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => role == 'admin'
              ? AdminHomeScreen(user: user, api: _api)
              : role == 'cliente'
                  ? ClientHomeScreen(user: user, api: _api)
                  : ProfileScreen(user: user, api: _api),
        ),
      );
    } on ApiException catch (_) {
      await _storage.deleteAll();
    } catch (_) {
      if (showSpinner) _showMessage('No se pudo conectar con el servidor');
    } finally {
      if (showSpinner && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMunicipios() async {
    if (_municipios.isNotEmpty || _loadingMunicipios) return;
    setState(() => _loadingMunicipios = true);
    try {
      _municipios = await _api.municipios();
      if (_municipios.isNotEmpty) _municipioId = _municipios.first['id'] as int;
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudieron cargar los municipios');
    } finally {
      if (mounted) setState(() => _loadingMunicipios = false);
    }
  }

  Future<void> _login() async {
    if (!_loginForm.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final result = await _api.login(
        _loginEmailController.text.trim(),
        _loginPasswordController.text,
      );
      await _api.saveTokens(
        result['token'] as String,
        result['refreshToken'] as String,
      );
      await _openProfile();
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo conectar con el servidor');
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
        email: _registerEmailController.text.trim(),
        password: _registerPasswordController.text,
        nombre: _nameController.text.trim(),
        municipioId: _municipioId!,
        role: _role,
      );
      _showMessage(result['message']?.toString() ?? 'Registro enviado');
      setState(() {
        _isLogin = true;
        _registerPasswordController.clear();
      });
    } on ApiException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('No se pudo conectar con el servidor');
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
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2147),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.jpg', fit: BoxFit.cover),
          const ColoredBox(color: Color(0x220F2147)),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                'assets/images/logo_mark.png',
                                width: _isLogin ? 280 : 210,
                                height: _isLogin ? 240 : 175,
                                fit: BoxFit.contain,
                                semanticLabel: 'Handy',
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Servicios confiables para tu hogar en Córdoba',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x33243250),
                                    border: Border.all(color: Colors.white54),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.location_on,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        '30 municipios de Córdoba',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  22,
                                  20,
                                  22,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x33D1D5DB),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(color: Colors.white38),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      _isLogin
                                          ? 'Iniciar sesión'
                                          : 'Crear cuenta',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (_isLogin)
                                      _loginFormWidget()
                                    else
                                      _registerFormWidget(),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              const Divider(color: Colors.white54),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _isLogin
                                          ? '¿Aún no tienes cuenta? '
                                          : '¿Ya tienes cuenta? ',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      setState(() => _isLogin = !_isLogin);
                                      if (!_isLogin) await _loadMunicipios();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      _isLogin
                                          ? 'Registrarse'
                                          : 'Inicia sesión',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_isLogin)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 8),
                  child: IconButton(
                    tooltip: 'Volver a iniciar sesión',
                    onPressed: () => setState(() => _isLogin = true),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0x44243250),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _loginFormWidget() {
    return Form(
      key: _loginForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Correo electrónico',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _emailField(controller: _loginEmailController, compact: true),
          const SizedBox(height: 18),
          const Text(
            'Contraseña',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _passwordField(controller: _loginPasswordController, compact: true),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showMessage(
                'Contacta al soporte para recuperar tu contraseña.',
              ),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFB7D7FF),
              ),
              child: const Text('¿Olvidaste tu contraseña?'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 58,
            child: _primaryButton(
              label: 'Iniciar sesión',
              onPressed: _login,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      onPressed: _loading ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFFF9D00),
        foregroundColor: const Color(0xFF0F2147),
        elevation: 8,
        shadowColor: const Color(0x99FF9D00),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      child: _loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF0F2147),
              ),
            )
          : Text(label),
    );
  }

  InputDecoration _glassDecoration({
    String? labelText,
    String? hintText,
    required String prefixEmoji,
    bool accentBorder = false,
    Widget? suffixIcon,
  }) {
    final borderColor =
        accentBorder ? const Color(0xFF65A9FF) : Colors.white54;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      hintStyle: const TextStyle(color: Colors.white70),
      labelStyle: const TextStyle(color: Colors.white),
      filled: true,
      fillColor: const Color(0x55E9EEF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF65A9FF), width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFD180)),
      prefixIcon: SizedBox(
        width: 44,
        child: Center(
          child: Text(
            prefixEmoji,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _roleCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final selected = _role == value;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _role = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x33FF9D00)
                : const Color(0x44E9EEF7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFFFF9D00) : Colors.white54,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFFF9D00) : Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: selected ? const Color(0xFF0F2147) : Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _registerFormWidget() {
    return Form(
      key: _registerForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _fieldLabel('¿Cómo usarás Handy?'),
          Row(
            children: [
              _roleCard(
                value: 'cliente',
                title: 'Cliente',
                subtitle: 'Busco servicio',
                icon: Icons.home_outlined,
              ),
              const SizedBox(width: 10),
              _roleCard(
                value: 'trabajador',
                title: 'Trabajador',
                subtitle: 'Ofrezco servicio',
                icon: Icons.build_outlined,
              ),
            ],
          ),
          if (_role == 'trabajador') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF1DD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info,
                    color: Color(0xFF3B82F6),
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tu cuenta quedará pendiente hasta la aprobación del administrador.',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _fieldLabel('Nombre completo'),
          TextFormField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: _glassDecoration(
              hintText: 'Ej. María Gómez',
              prefixEmoji: '👤',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Ingresa tu nombre'
                : null,
          ),
          const SizedBox(height: 14),
          _fieldLabel('Correo electrónico'),
          _emailField(controller: _registerEmailController, compact: true),
          const SizedBox(height: 14),
          _fieldLabel('Contraseña'),
          _passwordField(
            controller: _registerPasswordController,
            compact: true,
            hintText: 'Mín. 8 caracteres, 1 letra y 1 número',
          ),
          const SizedBox(height: 14),
          _fieldLabel('Municipio'),
          DropdownButtonFormField<int>(
            initialValue: _municipioId,
            dropdownColor: const Color(0xFF0F2147),
            iconEnabledColor: Colors.white,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: _glassDecoration(
              hintText: _loadingMunicipios
                  ? 'Cargando municipios...'
                  : 'Selecciona tu municipio',
              prefixEmoji: '📍',
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
          const SizedBox(height: 20),
          SizedBox(
            height: 56,
            child: _primaryButton(
              label: 'Crear cuenta',
              onPressed: _register,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailField({
    required TextController controller,
    bool compact = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: _glassDecoration(
        labelText: compact ? null : 'Correo electrónico',
        hintText: compact ? 'ejemplo@correo.com' : null,
        prefixEmoji: '✉️',
      ),
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Ingresa tu correo';
        if (!value.contains('@')) return 'Ingresa un correo válido';
        return null;
      },
    );
  }

  Widget _passwordField({
    required TextController controller,
    bool compact = false,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: _glassDecoration(
        labelText: compact ? null : 'Contraseña',
        hintText: hintText ?? (compact ? '••••••••' : null),
        prefixEmoji: '🔒',
        accentBorder: true,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: compact ? Colors.white70 : null,
          ),
        ),
      ),
      style: const TextStyle(color: Colors.white),
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
