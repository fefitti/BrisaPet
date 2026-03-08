import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const BrisaPetApp());
}

class BrisaPetApp extends StatelessWidget {
  const BrisaPetApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brisa Pet',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _abaAtual = 0;
  final List<String> _titulos = ['Perdidos', 'Adoção', 'Social'];
  final List<Color> _cores = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.green,
  ];

  final ImagePicker _picker = ImagePicker();
  List<XFile> _imagensSelecionadas = [];
  bool _estaCarregando = false;

  Future<void> _selecionarImagens() async {
    if (_imagensSelecionadas.length >= 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Limite de 3 fotos.")));
      return;
    }
    final List<XFile> imagens = await _picker.pickMultiImage(
      imageQuality: 70,
      maxWidth: 800,
    );
    if (imagens.isNotEmpty) {
      setState(() {
        _imagensSelecionadas.addAll(imagens);
        if (_imagensSelecionadas.length > 3) {
          _imagensSelecionadas = _imagensSelecionadas.sublist(0, 3);
        }
      });
    }
  }

  Future<void> _postar(String titulo, String desc, String contato) async {
    if (titulo.isEmpty || _imagensSelecionadas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Título e fotos são obrigatórios.")),
      );
      return;
    }

    setState(() {
      _estaCarregando = true;
    });

    List<String> urls = [];

    try {
      for (XFile img in _imagensSelecionadas) {
        String nome = '${DateTime.now().millisecondsSinceEpoch}_${img.name}';
        Reference ref = FirebaseStorage.instance.ref().child('posts/$nome');

        Uint8List bytes = await img.readAsBytes();
        await ref.putData(bytes);
        urls.add(await ref.getDownloadURL());
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'titulo': titulo,
        'descricao': desc,
        'contato': contato,
        'tipo': _titulos[_abaAtual],
        'fotos': urls,
        'data': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _imagensSelecionadas = [];
        _estaCarregando = false;
      });
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _estaCarregando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    }
  }

  void _abrirFormulario() {
    final tCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    final cCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text("Novo Brisa Pet"),
          content: _estaCarregando
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: tCtrl,
                        decoration: const InputDecoration(labelText: "Nome"),
                      ),
                      TextField(
                        controller: dCtrl,
                        decoration: const InputDecoration(
                          labelText: "Descrição",
                        ),
                      ),
                      TextField(
                        controller: cCtrl,
                        decoration: const InputDecoration(labelText: "Contato"),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _selecionarImagens();
                          setDialog(() {});
                        },
                        child: Text("Fotos (${_imagensSelecionadas.length}/3)"),
                      ),
                    ],
                  ),
                ),
          actions: _estaCarregando
              ? []
              : [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                  ElevatedButton(
                    onPressed: () =>
                        _postar(tCtrl.text, dCtrl.text, cCtrl.text),
                    child: const Text("Postar"),
                  ),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Brisa Pet: ${_titulos[_abaAtual]}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _cores[_abaAtual],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .where('tipo', isEqualTo: _titulos[_abaAtual])
            .orderBy('data', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final d = doc.data() as Map<String, dynamic>;
              final fotos = d['fotos'] as List<dynamic>?;
              return Card(
                child: Column(
                  children: [
                    if (fotos != null && fotos.isNotEmpty)
                      Image.network(
                        fotos[0],
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ListTile(
                      title: Text(d['titulo']),
                      subtitle: Text(
                        "${d['descricao']}\nContato: ${d['contato']}",
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormulario,
        child: const Icon(Icons.add_a_photo),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _abaAtual,
        onTap: (i) => setState(() => _abaAtual = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Perdidos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Adoção'),
          BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism),
            label: 'Social',
          ),
        ],
      ),
    );
  }
}
