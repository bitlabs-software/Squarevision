import 'dart:io';

import 'package:camera/camera.dart';
import 'package:chaquopy/chaquopy.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:squarevision/database_helper.dart';
import 'package:squarevision/pages/camera_page.dart';
import 'package:squarevision/pages/predict_page.dart';

import 'dart:async';

import 'package:squarevision/utils.dart';
import 'package:url_launcher/url_launcher.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  // Avoid errors caused by flutter upgrade.
  // Importing 'package:flutter/widgets.dart' is required.
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    //logError(e.code, e.description);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Squarevision',
      home: MyHomePage(title: 'Squarevision'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Board {
  Board({required this.id, required this.name, required this.fen});
  final int id;
  final String name;
  final String fen;
}

class _MyHomePageState extends State<MyHomePage> {
  int? _selected;
  List? positions = ["Bottom Left", "Bottom Right", "Top Left", "Top Right"];

  List? boardList = [];

  TextEditingController _fenTextFieldController = TextEditingController();
  TextEditingController _nameTextFieldController = TextEditingController();

  bool _validate = false;

  @override
  void dispose() {
    _fenTextFieldController.dispose();
    _nameTextFieldController.dispose();
    super.dispose();
  }

  // reference to our single class that manages the database
  final dbHelper = DatabaseHelper.instance;

  void refreshBoards() async {
    setState(() {
      boardList = [];
    });
    dbHelper.queryAllRows().then((value) {
      for (var element in value) {
        boardList!.add(Board(
            id: element['id'], name: element['name'], fen: element["fen"]));
      }
      setState(() {});
    }).catchError((error) {
      print(error);
    });
  }

  @override
  void initState() {
    super.initState();
    downloadModel();
    refreshBoards();
  }

  showChooseSquarePosDialog(BuildContext context) async {
    int selectedRadio = 0;

    // set up the button
    Widget okButton = TextButton(
      child: const Text("OK"),
      onPressed: () async {
        setState(() {
          _selected = selectedRadio;
        });
        print(_selected);
        Navigator.pop(context, true);
      },
    );

    return showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('A1 Square Position'),
            content: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List<Widget>.generate(4, (int index) {
                    return Row(children: [
                      Radio<int>(
                        value: index,
                        groupValue: selectedRadio,
                        onChanged: (int? value) {
                          setState(() => selectedRadio = value!);
                        },
                      ),
                      Text(positions![index])
                    ]);
                  }),
                );
              },
            ),
            actions: [
              okButton,
            ],
          );
        });
  }

  Future<void> _showAttributions() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Attributions'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text("Icons by https://icons8.com"),
                const SizedBox(height: 20),
                RichText(
                  text: TextSpan(
                    text: 'Github',
                    style: const TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        launchUrl(Uri.parse(
                            'https://github.com/bitlabs-software/Squarevision'));
                      },
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget slideLeftBackground() {
    return Container(
      color: Colors.red,
      child: Align(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: const <Widget>[
            Icon(
              Icons.delete,
              color: Colors.white,
            ),
            Text(
              " Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.right,
            ),
            SizedBox(
              width: 20,
            ),
          ],
        ),
        alignment: Alignment.centerRight,
      ),
    );
  }

  final _fenFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>();

  Future<void> _displayTextInputDialog(BuildContext context, int? index) async {
    return showDialog(
        barrierDismissible: true,
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Edit Board'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Form(
                key: _nameFormKey,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Enter Name',
                  ),
                  validator: (text) {
                    if (text!.length > 40) {
                      return "Max length is 40 characters";
                    }
                    if (text.isEmpty) {
                      return "Name can't be empty";
                    }
                    return null;
                  },
                  controller: _nameTextFieldController,
                ),
              ),
              Form(
                key: _fenFormKey,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Enter the FEN',
                  ),
                  validator: (text) {
                    if (!validate_fen(text)!['valid']) {
                      return 'FEN Validation Failed';
                    }
                    return null;
                  },
                  controller: _fenTextFieldController,
                ),
              ),
            ]),
            actions: <Widget>[
              FlatButton(
                color: Colors.black,
                textColor: Colors.white,
                child: const Text('OK'),
                onPressed: () {
                  if (_fenFormKey.currentState!.validate() &&
                      _nameFormKey.currentState!.validate()) {
                    _update(index! + 1, _nameTextFieldController.text,
                        _fenTextFieldController.text);
                    refreshBoards();
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          );
        });
  }

  Future<void> downloadModel() async {
    final _result = await Chaquopy.executeCode("""
from download_model import download

download()
""");
    String? _outputOrError = _result['textOutputOrError'] ?? '';

    print(_outputOrError);
    '''
      await showDialog(
          barrierDismissible: true,
          context: context,
          builder: (context) {
            return const AlertDialog(
                title: Text('Error'),
                content:
                    Text("There was an error downloading the required files"));
          });

      SystemChannels.platform.invokeMethod('SystemNavigator.pop');

      print(e);
      ''';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          flexibleSpace:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: const <Widget>[
                Padding(
                    padding: EdgeInsets.only(top: 10, left: 30),
                    child: SizedBox(
                        child: Text("YOUR BOARDS",
                            style: TextStyle(fontWeight: FontWeight.w700))))
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                      child: RawMaterialButton(
                    onPressed: () {
                      _showAttributions();
                    },
                    elevation: 0.0,
                    fillColor: const Color(0xffcbccc9),
                    child: const Icon(
                      Icons.info_outline,
                      size: 25.0,
                    ),
                    splashColor: Colors.transparent,
                    highlightElevation: 0,
                    highlightColor: Colors.transparent,
                    padding: const EdgeInsets.all(5.0),
                    shape: const CircleBorder(),
                  )),
                )
              ],
            ),
          ])),
      backgroundColor: Colors.white,
      body: boardList!.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Image(
                    image: AssetImage('assets/images/playing.png'),
                    width: double.infinity,
                    height: 225,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 125,
                    height: 50,
                    child: ElevatedButton(
                      child: const Text('Scan board'),
                      style: ElevatedButton.styleFrom(
                        primary: Colors.black,
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => CameraHomeScreen(cameras!)),
                        );

                        if (result != null) {
                          final success =
                              await showChooseSquarePosDialog(context);

                          if (success == true) {
                            String? fen = (await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => PredictPage(
                                          imgPath: result,
                                          selected: _selected!)),
                                ))
                                    .trim() +
                                ' w KQkq - 0 1';

                            print(fen);

                            Map? validation_map = validate_fen(fen);

                            if (validation_map!['valid']) {
                              _insert(
                                  "Board #" +
                                      (boardList!.length + 1).toString(),
                                  fen);

                              refreshBoards();
                            } else {
                              var snackBar = const SnackBar(
                                  content: Text(
                                      "The chessboard couldn't be detected!"));
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(snackBar);
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Scan a chessboard from a surface\n to save to your boards.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.only(left: 15, top: 15),
              child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: boardList!.length,
                  itemBuilder: (ctx, index) {
                    return Column(children: [
                      Dismissible(
                        background: Container(),
                        secondaryBackground: slideLeftBackground(),
                        key: Key(index.toString()),
                        child: InkWell(
                          onTap: () {},
                          child: ListTile(
                              title: Text(boardList![index].name.toString()),
                              trailing: IconButton(
                                icon:
                                    const Icon(Icons.edit, color: Colors.black),
                                onPressed: () {
                                  setState(() {
                                    _nameTextFieldController.text =
                                        boardList![index].name;
                                    _fenTextFieldController.text =
                                        boardList![index].fen;
                                  });
                                  _displayTextInputDialog(context, index);
                                },
                              ),
                              leading: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 44,
                                  minHeight: 44,
                                  maxWidth: 64,
                                  maxHeight: 64,
                                ),
                                child: Image.asset(
                                    'assets/images/chessboard.png',
                                    fit: BoxFit.cover),
                              ),
                              onTap: () async {
                                var url =
                                    "https://lichess.org/editor/${boardList![index].fen}";
                                if (!await launchUrl(Uri.parse(url))) {
                                  var snackBar = SnackBar(
                                      content: Text('Could not launch $url'));
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(snackBar);
                                }
                              }),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.endToStart) {
                            await showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    content: Text(
                                        "Are you sure you want to delete ${boardList![index].name}?"),
                                    actions: <Widget>[
                                      FlatButton(
                                        child: const Text(
                                          "Cancel",
                                          style: TextStyle(color: Colors.black),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                      FlatButton(
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        onPressed: () async {
                                          // TODO: Delete the item from DB etc..
                                          boardList!.removeAt(index);
                                          _delete(index + 1);
                                          Navigator.pop(context);
                                          setState(() {});
                                        },
                                      ),
                                    ],
                                  );
                                });
                          } else {
                            // TODO: Navigate to edit page;
                          }
                        },
                      ),
                      const SizedBox(height: 20)
                    ]);
                  })),
      floatingActionButton: boardList!.isNotEmpty
          ? FloatingActionButton(
              // isExtended: true,
              child: const Icon(Icons.add),
              backgroundColor: Colors.black,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => CameraHomeScreen(cameras!)),
                );

                if (result != null) {
                  final success = await showChooseSquarePosDialog(context);

                  if (success == true) {
                    String? fen = (await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => PredictPage(
                                  imgPath: result, selected: _selected!)),
                        ))
                            .trim() +
                        ' w KQkq - 0 1';

                    print(fen);

                    Map? validation_map = validate_fen(fen);

                    if (validation_map!['valid']) {
                      _insert(
                          "Board #" + (boardList!.length + 1).toString(), fen);

                      refreshBoards();
                    } else {
                      var snackBar = const SnackBar(
                          content:
                              Text("The chessboard couldn't be detected!"));
                      ScaffoldMessenger.of(context).showSnackBar(snackBar);
                    }
                  }
                }
              },
            )
          : Container(),
    ));
  }

  // Button onPressed methods

  void _insert(String? name, String? fen) async {
    // row to insert
    Map<String, dynamic> row = {
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnFen: fen
    };
    final id = await dbHelper.insert(row);
    // print('inserted row id: $id');
  }

  void _query() async {
    final allRows = await dbHelper.queryAllRows();
    // print('query all rows:');
    allRows.forEach(print);
  }

  void _update(int? id, String? name, String? fen) async {
    // row to update
    Map<String, dynamic> row = {
      DatabaseHelper.columnId: id,
      DatabaseHelper.columnName: name,
      DatabaseHelper.columnFen: fen
    };
    final rowsAffected = await dbHelper.update(row);
    // print('updated $rowsAffected row(s)');
  }

  void _delete(int? id) async {
    // Assuming that the number of rows is the id for the last row.
    // final id = await dbHelper.queryRowCount();
    final rowsDeleted = await dbHelper.delete(id!);
    // print('deleted $rowsDeleted row(s): row $id');
  }
}
