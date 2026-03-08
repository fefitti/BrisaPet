// Este teste verifica se o seu app Brisa Pet abre corretamente
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_lovers/main.dart'; // Importa seu arquivo principal

void main() {
  testWidgets('Verifica se o Brisa Pet abre e carrega o título', (WidgetTester tester) async {
    // Constrói o app usando a classe correta 'BrisaPetApp'
    await tester.pumpWidget(const BrisaPetApp());

    // Verifica se o título "Brisa Pet" está presente na tela
    expect(find.textContaining('Brisa Pet'), findsAtLeastNWidgets(1));
  });
}