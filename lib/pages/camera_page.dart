import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';

class CameraHomeScreen extends StatefulWidget {
  List<CameraDescription> cameras;

  CameraHomeScreen(this.cameras);

  @override
  State<StatefulWidget> createState() {
    return _CameraHomeScreenState();
  }
}

class _CameraHomeScreenState extends State<CameraHomeScreen> {
  String? imagePath;
  bool _toggleCamera = false;
  CameraController? controller;

  @override
  void initState() {
    try {
      onCameraSelected(widget.cameras[0]);
    } catch (e) {
      print(e.toString());
    }
    super.initState();
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget buildCameraPreview(CameraController cameraController) {
    final double previewAspectRatio = 0.7;
    return AspectRatio(
      aspectRatio: 1 / previewAspectRatio,
      child: ClipRect(
        child: Transform.scale(
          scale: cameraController.value.aspectRatio / previewAspectRatio,
          child: Center(
            child: CameraPreview(cameraController),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameras.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16.0),
        child: const Text(
          'No Camera Found',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      );
    }

    if (!controller!.value.isInitialized) {
      return Container();
    }

    final scale = 1 /
        (controller!.value.aspectRatio *
            MediaQuery.of(context).size.aspectRatio);
    return AspectRatio(
        aspectRatio: controller!.value.aspectRatio,
        child: Container(
            child: Stack(children: <Widget>[
          Center(
              child: Transform.scale(
                  alignment: Alignment.topCenter,
                  scale: scale,
                  child: Center(child: CameraPreview(controller!)))),
          Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                  width: double.infinity,
                  height: 120.0,
                  padding: const EdgeInsets.all(20.0),
                  color: const Color.fromRGBO(00, 00, 00, 0.7),
                  child: Stack(children: <Widget>[
                    Align(
                        alignment: Alignment.center,
                        child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(50.0)),
                              onTap: () {
                                controller!.setFlashMode(FlashMode.off);
                                _captureImage();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4.0),
                                child: Image.asset(
                                  'assets/images/ic_shutter_1.png',
                                  width: 72.0,
                                  height: 72.0,
                                ),
                              ),
                            )))
                  ])))
        ])));
  }

  void onCameraSelected(CameraDescription cameraDescription) async {
    if (controller != null) await controller!.dispose();
    controller = CameraController(cameraDescription, ResolutionPreset.max, enableAudio: false);

    controller!.addListener(() {
      if (mounted) setState(() {});
      if (controller!.value.hasError) {
        showMessage('Camera Error: ${controller!.value.errorDescription}');
      }
    });

    try {
      await controller!.initialize();
    } on CameraException catch (e) {
      showException(e);
    }

    if (mounted) setState(() {});
  }

  String timestamp() => new DateTime.now().millisecondsSinceEpoch.toString();

  Future<String> _resizePhoto(String filePath) async {
    var imgProperties = await FlutterNativeImage.getImageProperties(filePath);
    var croppedImage;
    if (imgProperties.width! > imgProperties.height!) {
      croppedImage = await FlutterNativeImage.cropImage(
          filePath,
          (imgProperties.width! ~/ 2) - (imgProperties.height! ~/ 2),
          0,
          imgProperties.height!,
          imgProperties.height!);
    } else {
      croppedImage = await FlutterNativeImage.cropImage(
          filePath,
          0,
          (imgProperties.height! ~/ 2) - (imgProperties.width! ~/ 2),
          imgProperties.width!,
          imgProperties.width!);
    }

    return croppedImage.path;
  }

  void _captureImage() {
    takePicture().then((File? file) async {
      final filePath = await _resizePhoto(file!.path);
      if (mounted) {
        setState(() {
          imagePath = filePath;
        });
        showMessage('Picture saved to $filePath');
        setCameraResult();
      }
    });
  }

  void setCameraResult() {
    Navigator.pop(context, imagePath);
  }

  Future<File?> takePicture() async {
    if (!controller!.value.isInitialized) {
      showMessage('Error: select a camera first.');
      return null;
    }
    final Directory extDir = await getApplicationDocumentsDirectory();
    final String dirPath = '${extDir.path}/FlutterDevs/Camera/Images';
    await new Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller!.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return null;
    }

    try {
      XFile picture = await controller!.takePicture();
      picture.saveTo(filePath);
      return File(picture.path);
    } on CameraException catch (e) {
      showException(e);
      return null;
    }
  }

  void showException(CameraException e) {
    logError(e.code, e.description!);
    showMessage('Error: ${e.code}\n${e.description}');
  }

  void showMessage(String? message) {
    print(message);
  }

  void logError(String code, String message) =>
      print('Error: $code\nMessage: $message');
}
