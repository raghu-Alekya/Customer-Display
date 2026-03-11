import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../Constants/text.dart';
import '../Models/Auth/login_model.dart';


String appDocDirPath = "";

class FileHelper {

  final String _fileName;
  FileHelper(this._fileName){
    if (kDebugMode) {
      print("  FileHelper.Constructor $_fileName");
    }
    if(appDocDirPath == "") {
      _localPath;
    }
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    appDocDirPath = directory.path;
    if (kDebugMode) {
      print("  FileHelper._localPath ${directory.path}");
    }
    return directory.path;
  }

  Future<File> get _loadFile async {
    String path = appDocDirPath;
    if(path == "") {
      path = await _localPath;
    }
    if (kDebugMode) {
      print("  FileHelper._loadFile $path/$_fileName");
    }
    return File('$path/$_fileName');
  }

  Future<dynamic> readJSONImageFileData () async {
    try {
      final file = await _loadFile; //("some${TextConstants.jsonfileExtension}")
      String contents = await file.readAsString();
      json.decode(contents);
      final jsonResponse = contents.toString(); //jsonDecode(contents);
      if (kDebugMode) {
        // print("  FileHelper.readJSONFileData contents:  $contents ${jsonResponse.toString()}");
      }
      // LoginResponse response = LoginResponse.fromJson(jsonResponse);
      return jsonResponse;
    } catch (e) {
      if (kDebugMode) {
        print("Exception in readJSONFileData $e");
      }
      return "";
    }
  }

  Future<dynamic> readJSONFileData () async {
    try {
      final file = await _loadFile; //("some${TextConstants.jsonfileExtension}")
      if (!await file.exists()) {  //Build 1.1.200: added condition for resolve exception
        if (kDebugMode) {
          print("File not found at path");
        }
        return "";
      }
      String contents = await file.readAsString();
      if (kDebugMode) {
       print("  FileHelper.readJSONFileData contents:  contents");
      }
      final jsonResponse = jsonDecode(contents);
      // LoginResponse response = LoginResponse.fromJson(jsonResponse);
      return jsonResponse;
    } catch (e,s) {
      if (kDebugMode) {
        print("Exception in readJSONFileData $e ; Stack: $s");
      }
      return "";
    }
  }

  Future<void> writeBytesDataToFile(List<List<int>> chunks, int contentLength, {bool append = false}) async {
    final file = await  _loadFile;
    final Uint8List bytes = Uint8List(contentLength);
    int offset = 0;
    for (List<int> chunk in chunks) {
      bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    await file.writeAsBytes(bytes); /// encrypt file after download and delete after read and store in db
  }

  Future<File> writeJOSNDataToFile(String response, {bool append = false}) async {

    if (kDebugMode) {
      print("##### FileHelper.writeJOSNDataToFile(/*response*/) ${Platform.lineTerminator} append : $append");
    }
    final file = await  _loadFile; // ("some${TextConstants.jsonfileExtension}");
    if(append) {
      await file.writeAsString(response, mode: FileMode.append);
    } else {
      await file.writeAsString(response);
    }
    if (kDebugMode) {
      // try {
      //   String contents = await file.readAsString();
      //   print(" FileHelper.writeJOSNDataToFile.contents = $contents");
      // }
      // catch (e) {
      //   if (kDebugMode) {
      //     print("Exception in writeJOSNDataToFile $e");
      //   }
      // }
    }
    return file; //response.toJson().toString()
  }

  Future<File> getFile() async {
    final file = await  _loadFile;
    return file;
  }

  Future<bool> exists() async {
    final file = await  _loadFile;
    return file.exists();
  }

  Future<bool> delete() async {
    final file = await  _loadFile;
    FileSystemEntity entry = await file.delete();
    return entry.exists();
  }

  static Future<String?> readToken() async {

  }

  static Future<LoginResponse?> readLoginResponse() async { // Build #1.0.11: Added for User Id from login response
    try {
      FileHelper fileHelper = FileHelper(
          "${TextConstants.login}${TextConstants.jsonfileExtension}");
      dynamic contents = await fileHelper.readJSONFileData();
      return LoginResponse.fromJson(contents);
    } catch (e) {
      if (kDebugMode) {
        print("Exception in FileHelper.readLoginResponse: $e");
      }
      return null;
    }
  }

}
