
/**
 * Common logic to make it easy to add couchdb deployment to a `build.dart` for your project.
 *
 * The `build.dart` script is invoked automatically by the Editor whenever a
 * file in the project changes. It must be placed in the root of a project
 * (where pubspec.yaml lives) and should be named exactly 'build.dart'.
 *
 * A common `build.dart` would look as follows:
 *
 *     import 'dart:io';
 *     import 'package:web_ui/component_build.dart';
 *     import 'package:lounge/deploy_couchdb.dart';
 *
 *     main() {
 *       build(new Options().arguments, ['web/index.html']);
 *       deploy(['<name_of_directory>'], 'https://<username>:<password>@<cloudDb_db_url>');
 *     }
 *
 *
 */
library deploy_utils;

import 'dart:io';
import 'dart:async';
import 'dart:uri';
import 'dart:crypto';
import 'dart:json';

/**
 * Set up 'build.dart' to deploy every file in
 * [deployDirectories] listed. 
 */
List<String> directoriesToDeploy;

deploy(List<String> deployDirectories, String dbUrl) {
  directoriesToDeploy = deployDirectories;
  List filesToSend = getCurrentProjectFiles();
  List<File> filteredFiles = getFilteredFiles(filesToSend);
  Map fileMap = getFileMapToUpload(filteredFiles);
  Future processFiles = Future.forEach(fileMap.keys, (documentName){
    print('current document is $documentName');
    return getRevision(documentName, dbUrl)
        .then((revision) => uploadFiles(revision['_rev'], fileMap[documentName], dbUrl))
        .then((result) => showResults(result));
  });
  processFiles.then((result){
    print('finished');
  });
}
Future showResults(result) {
  print('result is $result');
  return new Future.immediate('done');
}

Future uploadFiles(revision, document, dbUrl) {
  print('revision is $revision');
  if(revision == null){
    document['_rev'] = revision;
  }
  print('document is ${document['_id']}');
  var baseUri = new Uri.fromString('$dbUrl/${document['_id']}');
  var jsonData = stringify(document);
  Completer c = new Completer();
  String httpMethod = 'PUT';
  HttpClient client = new HttpClient();
  HttpClientConnection conn = client.openUrl('PUT', baseUri);
  conn.onRequest = (HttpClientRequest req){
    //print('in request');
    req.headers.set(HttpHeaders.ACCEPT, "application/json");
    if (httpMethod == "POST" || httpMethod == "PUT") {
      req.headers.set(HttpHeaders.CONTENT_TYPE, "application/json");
      req.headers.forEach((value, values){
        if(value == 'referer')
          print('value is $values');
        });
        if (jsonData != null) {
          req.contentLength = jsonData.length; 
          print('about to write ${jsonData.length} bytes');
          req.outputStream.writeString(jsonData);
        }
        else {
          req.contentLength = 0;
        }
      }
      req.outputStream.close();
    };
    
    conn.onResponse = (HttpClientResponse res){
      //print('in response');
      var resReason = res.reasonPhrase;
      res.inputStream.onData = () {
        String encodedResult = new String.fromCharCodes(res.inputStream.read());
        //print(encodedResult);
        c.complete(parse(encodedResult));
      };
      res.inputStream.onClosed = () {
        client.shutdown();
      };
    };
    conn.onError = (Exception e){
      
      print(e);
    };
    return c.future;

}

Future getRevision(String documentName, dbUrl) {
  Completer c = new Completer();
  var baseUri = new Uri.fromString('$dbUrl/$documentName');
  String httpMethod = 'GET';
  HttpClient client = new HttpClient();
  HttpClientConnection conn = client.getUrl(baseUri);
  conn.onRequest = (HttpClientRequest req){
    //print('in request');
    req.headers.set(HttpHeaders.ACCEPT, "application/json");
    req.outputStream.close();
  };
  conn.onResponse = (HttpClientResponse res){
    //print('in response');
    final StringInputStream input = new StringInputStream(res.inputStream);
    StringBuffer buffer = new StringBuffer('');
    var resReason = res.reasonPhrase;
    input.onData = () {
      buffer.add(input.read());
    };
    input.onClosed = () {
      client.shutdown();
      Object response = null;
      if (buffer != null && !buffer.isEmpty) {
        String data = buffer.toString();
        try {
          response = parse(data);
        }
        catch(e) { return; }
      }
      c.complete(response);
    };
  };
  conn.onError = (Exception e){
    c.completeError(e);
  };
  return c.future;
}

Map getFileMapToUpload(filesToProcess) {
  Map postData = new Map();
  Map attachments = new Map();
  Map targetDocument = new Map();
  for(final currentFile in filesToProcess){
    if(currentFile is Directory){
      continue;
    }
    //get data and content type
    var attachmentToUpload = new Map();
    var currentBytes = currentFile.readAsBytesSync();
    var dataBase64 = CryptoUtils.bytesToBase64(currentBytes);
    attachmentToUpload['data'] = dataBase64;
    attachmentToUpload['content_type'] = encodeUri(getMimeType(currentFile));
    //get current directory
    var pathList = currentFile.name.split('/');
    var pathListLength = pathList.length;
    var targetDirectory = pathList[pathListLength - 2];
    var shortName = pathList.last;
    if(postData[targetDirectory] == null){
      postData[targetDirectory] = new Map();
      postData[targetDirectory]['_id'] = targetDirectory;
      postData[targetDirectory]['_attachments'] = new Map();
    }
    postData[targetDirectory]['_attachments'][shortName] = attachmentToUpload;
    postData[targetDirectory]['_id'] = targetDirectory;
  }
  return postData;
}

List<File> getFilteredFiles(sourceList) {
  var filteredProcessFiles = sourceList.where((currentFile){
    return (currentFile is File && isProjectFile(currentFile.name));
  }).toList();
  return filteredProcessFiles;
}

List getCurrentProjectFiles() {
  var dir = new Directory('.');
  List contents = dir.listSync(recursive:true);
  List processFiles = new List();
  for (var fileOrDir in contents) {
    if (fileOrDir is Directory && isProjectFolder(fileOrDir.path)) {
      List temp = fileOrDir.listSync(recursive:false);
      processFiles.addAll(temp);
    }
  }
  return processFiles;
}
 
bool isProjectFolder(currentPath) {
  bool result = false;
    directoriesToDeploy.forEach((dir){
      if(currentPath.endsWith(dir)){
        result = true;
      }
    });
    return result;
}

bool isProjectFile(String path) {
  return (path.endsWith(".js") 
      || path.endsWith(".html")
      || path.endsWith(".png")
      || path.endsWith(".jpg")
      || path.endsWith(".gif")
      || path.endsWith(".css")
      || path.endsWith(".dart")
      );
}
String getMimeType(file){
  String mimeType = "text/html; charset=UTF-8";
  int lastDot = file.name.lastIndexOf(".", file.name.length);
  if (lastDot != -1) {
    String extension = file.name.substring(lastDot);
    if (extension == ".css") { mimeType = "text/css"; }
    if (extension == ".js") { mimeType = "application/javascript"; }
    if (extension == ".dart") { mimeType = "application/dart"; }
    if (extension == ".ico") { mimeType = "image/vnd.microsoft.icon"; }
    if (extension == ".png") { mimeType = "image/png"; }
    if (extension == ".jpg") { mimeType = "image/jpg"; }
    if (extension == ".gif") { mimeType = "image/gif"; }
  }
  return mimeType;
}