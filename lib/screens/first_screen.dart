import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart';
import 'package:path/path.dart';

class FirstScreen extends StatefulWidget {
  const FirstScreen({super.key});

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Test Task'),
      ),
      body: CameraView(),
    );
  }
}

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  List<CameraDescription>? _cameras;
  CameraController? _controller;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _getAvailableCameras();
    requestLocationPermission();
  }

  Future<void> requestLocationPermission() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      var newStatus = await Permission.location.request();

      if (newStatus.isGranted) {
        print("Разрешение предоставлено");
      } else if (newStatus.isDenied) {
        print("Разрешение отклонено");
      } else if (newStatus.isPermanentlyDenied) {
        print("Разрешение отклонено навсегда. Переход в настройки.");
        openAppSettings();
      }
    } else if (status.isGranted) {
      print("Разрешение уже предоставлено");
    }
  }

  Future<void> _getAvailableCameras() async {
    try {
      final cameras = await availableCameras();
      setState(() {
        _cameras = cameras;
        _setCameraController(_cameras?.first);
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _setCameraController(CameraDescription? cameraDescription) async {
    if (_controller != null) {
      await _controller!.dispose();
    }
    _controller = CameraController(cameraDescription!, ResolutionPreset.high, imageFormatGroup: ImageFormatGroup.jpeg);

    _controller!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    try {
      await _controller?.initialize();
    } on CameraException catch (e) {
      print(e);
    }

    if (mounted) {
      setState(() {});
    }
  }

  Widget _cameraPreview() {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: CameraPreview(_controller!),
    );
  }

  Future<void> _takePictureAndSendToServer(String? comment) async {
    if (!_controller!.value.isInitialized) {
      return;
    }

    if (_controller!.value.isTakingPicture) {
      return;
    }

    try {
      XFile image = await _controller!.takePicture();
      final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      var uri = Uri.parse("https://camera-test-task.free.beeceptor.com/upload_photo");
      List<int> imageBytes = await image.readAsBytes();
      var request = MultipartRequest('POST', uri)
        ..fields['comment'] = comment ?? ''
        ..fields['latitude'] = position.latitude.toString()
        ..fields['longitude'] = position.longitude.toString()
        ..files.add(MultipartFile.fromBytes('photo', imageBytes, filename: basename(image.path)));
      request.headers['Content-Type'] = 'application/javascript';
      var response = await request.send();
      if (response.statusCode == 200) {
        print('Изображение успешно отправлено на сервер');
      } else {
        print('Не удалось отправить изображение на сервер, ошибка ${response.statusCode}');
      }
    } on CameraException catch (e) {
      print(e);
    }
  }

  Color primaryColor = const Color.fromRGBO(17, 39, 99, 1);

  @override
  Widget build(BuildContext context) {
    TextEditingController textEditingController = TextEditingController();
    return SafeArea(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          margin: const EdgeInsets.all(10),
          height: MediaQuery.of(context).size.height / 1.5,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), border: Border.all()),
          child: _cameraPreview(),
        ),
        Row(children: [
          Container(
            margin: const EdgeInsets.all(10),
            width: MediaQuery.of(context).size.width / 2,
            height: 50,
            child: TextField(
                controller: textEditingController,
                decoration: const InputDecoration(hintText: 'Enter a comment')),
          ),
          ElevatedButton(
            onPressed: () {
              _takePictureAndSendToServer(textEditingController.text);
            },
            child: Text(
              'Send Request',
              style: TextStyle(
                fontSize: 20,
                fontFamily: GoogleFonts.josefinSans().fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ])
      ],
    ));
  }
}
