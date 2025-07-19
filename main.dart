import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:ocr/result_screen.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Text Recognition',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget{

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver{
  bool _isPermissionGranted = false;

  late final Future<void> _future;

  CameraController? _cameraController;

  final _textRecognizer = TextRecognizer();

  @override
  void initState(){
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _future = _requestCameraPermission();
  }

  @override
  void dispose(){
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state){

    if(_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if(state == AppLifecycleState.inactive){
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
    _cameraController != null &&
    _cameraController!.value.isInitialized){
      _startCamera();
    }
  }


  @override
  Widget build(BuildContext context){

    return FutureBuilder(
        future: _future,
        builder: (context, snapshot){
          return Stack(
            children: [
              //show the camera feed behind everything
              if(_isPermissionGranted)
                FutureBuilder<List<CameraDescription>>(
                  future: availableCameras(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      _initCameraController(snapshot.data!);

                      return Center(child: CameraPreview(_cameraController!),);
                    } else {
                      return const LinearProgressIndicator();
                    }
                  }
                ),
                Scaffold(
                    appBar: AppBar(
                      title: Text(
                        "TEXT RECOGNITION",
                        style: TextStyle(
                          color: Colors.white, // Set the text color to white
                          fontSize: 20.0, // Set the font size
                          fontWeight: FontWeight.bold, // Set the font weight
                          fontStyle: FontStyle.italic, // Set the font style
                          // You can add more font styles as needed
                        ),
                      ),
                      backgroundColor: Colors.brown,
                      centerTitle: true, // Center the title text
                    ),
                  backgroundColor:
                      _isPermissionGranted ? Colors.transparent : null,
                  body: _isPermissionGranted
                    ? Column(
                    children: [
                      Expanded(
                        child: Container(),
                      ),
                      Container(
                        padding: const EdgeInsets.only(bottom: 30.0),
                        child: Center(
                          child: ElevatedButton(
                              onPressed: _scanImage,
                              child: Text("Scan Text"),
                          ),
                        ),
                      )
                    ],
                  )
                      : Center(
                        child: Container(
                          padding: const EdgeInsets.only(
                            left: 24.0,
                            right: 24.0,
                      ),
                      child: const Text("Camera permission denied",
                      textAlign: TextAlign.center,
                      ),
                    ),
                  )
                )
            ],
          );
        }
    );
  }


  Future<void> _requestCameraPermission() async {

    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;
  }

  Future<void> _requestCameraPermission1() async {

    final status = await Permission.camera.request();

    _isPermissionGranted = status == PermissionStatus.granted;
  }

  void _startCamera(){
    if (_cameraController != null){
      _cameraSelected(_cameraController!.description);
    }
  }

  void _stopCamera(){
    if (_cameraController != null){
      _cameraController?.dispose();
    }
  }

  void _initCameraController(List<CameraDescription> Cameras){
    if (_cameraController != null){
      return;
    }

    // Select the first rear camera.
    CameraDescription? camera;
    for (var i = 0; i < Cameras.length; i++){
      final CameraDescription current = Cameras[i];
      if (current.lensDirection == CameraLensDirection.back){

        camera = current;
        break;
      }
    }

    if (camera != null){
      _cameraSelected(camera);
    }
  }

  Future<void> _cameraSelected(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.max,
      enableAudio: false,
    );

    // Set the flash mode to off
    _cameraController?.setFlashMode(FlashMode.off);

    await _cameraController?.initialize();

    if (!mounted) {
      return;
    }
    setState(() {});
  }


  Future<void> _scanImage() async {
    if (_cameraController == null) return;

    final navigator = Navigator.of(context);

    try {
      // Set flash mode to off just before taking a picture
      await _cameraController?.setFlashMode(FlashMode.off);

      final pictureFile = await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage = InputImage.fromFile(file);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      await navigator.push(
        MaterialPageRoute(
          builder: (context) => ResultScreen(text: recognizedText.text),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("An Error occurred when scanning text."),
        ),
      );
    }
  }

}