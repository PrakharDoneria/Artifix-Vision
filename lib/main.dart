import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Artifix Vision',
      theme: CupertinoThemeData(
        brightness: Brightness.dark,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final picker = ImagePicker();
  File? _imageFile;
  String? _prompt;
  String? _errorMessage;
  String? _answer;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _imageFile = null;
    UnityAds.init(
      gameId: '5122862',
      onComplete: () {
        UnityAds.load(
          placementId: 'Interstitial_Android',
          onComplete: (placementId) => print('Load Complete $placementId'),
          onFailed: (placementId, error, message) =>
              print('Load Failed $placementId: $error $message'),
        );
      },
      onFailed: (error, message) =>
          print('Initialization Failed: $error $message'),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> getImage() async {
    final pickedFile =
        await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> uploadImageAndPrompt() async {
    if (_imageFile?.path == null || _prompt == null) {
      setState(() {
        _errorMessage = 'Please select an image and enter a prompt.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      var imgbbResponse = await http.post(
        Uri.parse(
            'https://api.imgbb.com/1/upload?key=8fe75b96cfb68c615e90cb6433e509a1'),
        body: {'image': base64Encode(_imageFile!.readAsBytesSync())},
      );

      if (imgbbResponse.statusCode != 200) {
        throw Exception('Failed to upload image to ImgBB');
      }

      var imgbbData = jsonDecode(imgbbResponse.body);
      var imageUrl = imgbbData['data']['url'];

      var backendResponse = await http.get(
        Uri.parse(
            'https://gemini-vision-five.vercel.app/vision?url=$imageUrl&prompt=$_prompt'),
      );

      if (backendResponse.statusCode != 200) {
        throw Exception('Failed to get response from backend server');
      }

      var responseData = jsonDecode(backendResponse.body);
      var answer = responseData['answer'];

      setState(() {
        _answer = answer;
        _isUploading = false;
        _showAnswerPopup(context);
      });

      UnityAds.showVideoAd(
        placementId: 'Interstitial_Android',
        onStart: (placementId) => print('Video Ad $placementId started'),
        onClick: (placementId) => print('Video Ad $placementId click'),
        onSkipped: (placementId) => print('Video Ad $placementId skipped'),
        onComplete: (placementId) {
          print('Video Ad $placementId completed');
        },
        onFailed: (placementId, error, message) =>
            print('Video Ad $placementId failed: $error $message'),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isUploading = false;
      });
    }
  }

  void _showAnswerPopup(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoAlertDialog(
          title: Text('Answer'),
          content:
              _answer != null ? Text(_answer!) : CupertinoActivityIndicator(),
          actions: [
            CupertinoDialogAction(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _answer = null;
                });
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Artifix Vision'),
      ),
      child: Container(
        color: CupertinoColors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CupertinoButton(
                onPressed: getImage,
                child: Text('Pick Image'),
              ),
              SizedBox(height: 20),
              _imageFile != null
                  ? Container(
                      height: 200,
                      width: 200,
                      child: Image.file(
                        _imageFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 200,
                      width: 200,
                      color: CupertinoColors.lightBackgroundGray,
                      child: Center(
                        child: Text(
                          'No Image Selected',
                          style: TextStyle(color: CupertinoColors.white),
                        ),
                      ),
                    ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CupertinoTextField(
                  onChanged: (value) {
                    setState(() {
                      _prompt = value;
                    });
                  },
                  placeholder: 'Enter prompt',
                  decoration: BoxDecoration(
                    border: Border.all(color: CupertinoColors.white),
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                  style: TextStyle(color: CupertinoColors.white),
                  placeholderStyle: TextStyle(color: CupertinoColors.white),
                ),
              ),
              SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: CupertinoButton(
                  onPressed: uploadImageAndPrompt,
                  child: _isUploading ? CupertinoActivityIndicator() : Text('Submit'),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: CupertinoColors.systemRed),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
