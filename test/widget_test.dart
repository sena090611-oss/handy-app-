import 'package:flutter_test/flutter_test.dart';

import 'package:handy_app/main.dart';

void main() {
  testWidgets('Muestra los controles de autenticacion', (tester) async {
    await tester.pumpWidget(const HandyApp());

    expect(find.bySemanticsLabel('Handy'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Registrarse'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
