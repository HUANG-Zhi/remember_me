import 'dart:convert';
import 'dart:io';
import 'file_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:storage_path/storage_path.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RememberMe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
      ),
      home: MyHomePage(title: 'RememberMe'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver{
  List<WeightPath> currentWeightedPaths = [];
  int currentWeightIndex = 0;
  String currentDirectory;
  Map<String,List<String>> imageFiles = {};
  final int hotSize = 9;

  PageController controller = new PageController();
  static final Color _themeColor = Colors.brown.shade900;

  var pageOffset = 0.0;
  var width = 100.0;
  final _biggerFont = const TextStyle(fontSize: 18.0);
  //final _buttonFont = TextStyle(color: _themeColor);
  final _currentDirectoryKey = 'Remember_CurrentDirectoryKey';
  int _tabIndex = 0;

  @override
  void initState() {
    //print('init load image');
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    loadImages();
    controller.addListener(() {
      setState(() {
        pageOffset = controller.offset / this.width;
        currentWeightIndex = pageOffset.round();
        //print(currentWeightIndex.toString()+","+pageOffset.toString()+","+controller.offset.toString()+","+this.width.toString());
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        reFresh();
      });
    }
  }

  Future<void> loadImages() async {
    String imagePath = '';
    try {
      //print('start load image');
      imagePath = await StoragePath.imagesPath;
      //print('end load image:'+imagePath);
      var response = jsonDecode(imagePath);
      var imageList = response as List;
      List<FileModel> listDirectories =
      imageList.map<FileModel>((json) => FileModel.fromJson(json)).toList();
      SharedPreferences prefs = await SharedPreferences.getInstance();

      setState(() {
        listDirectories.forEach((directory) => imageFiles[directory.folder] = directory.files);
        currentDirectory = prefs.getString(_currentDirectoryKey);
        if(currentDirectory == null) {
          currentDirectory = listDirectories[0].folder;
        }
        _loadCurrentDirectory(prefs);
      });
    } on Exception {
      imagePath = 'Failed to get path';
    }
    return imagePath;
  }

  _loadCurrentDirectory(SharedPreferences prefs){
    currentWeightedPaths = imageFiles[currentDirectory].map((filePath) => new WeightPath(filePath,currentDirectory,prefs)).toList();
    currentWeightedPaths.sort((a,b) => a.compareTo(b));
    currentWeightedPaths = currentWeightedPaths.sublist(0,hotSize);
    currentWeightIndex = 0;
    if(currentWeightedPaths.length > 0){
      currentWeightedPaths[currentWeightIndex].updateRate();
      _tabIndex = RateType.values.indexOf(currentWeightedPaths[currentWeightIndex].rateType);
    }
  }

  reFresh() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _loadCurrentDirectory(prefs);
    prefs.setString(_currentDirectoryKey,currentDirectory);
  }

  @override
  Widget build(BuildContext context) {
    final size =MediaQuery.of(context).size;
    final width = size.width;
    //final height = size.height;
    this.width = size.width;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          new IconButton(icon: new Icon(Icons.list), onPressed: _selectDirectory),
        ],
      ),
      body: Center(
        child: Container(
          child: PageView(
            controller: controller,
            children: currentWeightedPaths
                .map((item) => buildPageItem(currentWeightedPaths.indexOf(item), item, width))
                .toList(),
            onPageChanged: (index){
              currentWeightedPaths[index].updateRate();
            },
          ),
          width: width,
          color: Colors.black.withOpacity(0.8),
        ),
      ),
      bottomNavigationBar: new BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          new BottomNavigationBarItem(
              icon: new Icon(Icons.sentiment_very_satisfied), title: new Text("Good"),backgroundColor: Colors.black.withOpacity(0.85)),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.sentiment_satisfied), title: new Text("Easy"),backgroundColor: Colors.black.withOpacity(0.85)),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.sentiment_neutral), title: new Text("SoSo"),backgroundColor: Colors.black.withOpacity(0.85)),
          new BottomNavigationBarItem(
              icon: new Icon(Icons.sentiment_very_dissatisfied), title: new Text("Hard"),backgroundColor: Colors.black.withOpacity(0.85)),
        ],
        currentIndex: _tabIndex,
        onTap: (index) {
          setState(() {
            if(currentWeightedPaths.length > 0) {
              currentWeightedPaths[currentWeightIndex].updateRate(
                  RateType.values[index]);
            }
          });
        },
        backgroundColor: Colors.black,
      ),
    );
  }

  void _selectDirectory() {
    Navigator.of(context).push(
      new MaterialPageRoute(
        builder: (context) {
          var tiles = imageFiles.keys.map(
                  (selectedDirectory) => _buildRow(selectedDirectory)
          );
          var divided = ListTile
              .divideTiles(
            context: context,
            tiles: tiles,
          ).toList();

          return new Scaffold(
            appBar: new AppBar(
              title: new Text('Category'),
            ),
            body: new ListView(children: divided),
          );
        },
      ),
    );
  }

  Widget _buildRow(String selectedDirectory) {
    final alreadySaved = (selectedDirectory == currentDirectory);
    return new ListTile(
      title: new Text(
        selectedDirectory,
        style: _biggerFont,
      ),
      trailing: new Icon(
        alreadySaved ? Icons.favorite_border: Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),
      onTap: () {
        setState(() {
          currentDirectory = selectedDirectory;
          reFresh();
          Navigator.of(context).pop();
        });
      },
    );
  }
  Widget buildPageItem(int index, WeightPath weightPath, double width) {
    var currentLeftPageIndex = pageOffset.floor();
    var currentPageOffsetPercent = pageOffset - currentLeftPageIndex;
    _tabIndex = RateType.values.indexOf(currentWeightedPaths[currentWeightIndex].rateType);
    return Transform.translate(
      offset: Offset((pageOffset - index) * width, 0),
      child: Transform.scale(
        scale: currentLeftPageIndex == index
            ? 1 - currentPageOffsetPercent
            : currentPageOffsetPercent,
        child: Image.file(File(weightPath.filePath)),
      ),
    );
  }
}

enum RateType{
  Good,
  Easy,
  SoSo,
  Hard
}

class WeightPath {
  String directory;
  String fileName;
  String filePath;
  RateType rateType;
  DateTime lastUpdate;
  String pathKey;

  SharedPreferences dataSource;

  WeightPath(String filePath,String directory,SharedPreferences dataSource) {
    this.dataSource = dataSource;
    this.directory = directory;
    this.filePath = filePath;
    this.rateType = RateType.Easy;
    this.lastUpdate = DateTime.now();
    this.pathKey = this.directory + '/' + this.filePath.split('/').last;

    String stringValues = dataSource.get(this.pathKey);
    if(stringValues != null){
      fromString(stringValues);
    }
  }

  updateRate([RateType rateType]) async{
    if(rateType != null){
      this.rateType = rateType;
    }
    this.lastUpdate = DateTime.now();
    dataSource.setString(this.pathKey, toString());
    //print(this.pathKey+':'+toString());
  }


  int compareTo(WeightPath other){
    if(this.rateType.index > other.rateType.index){
      return -1;
    }

    if(this.rateType.index < other.rateType.index){
      return 1;
    }

    return this.lastUpdate.compareTo(other.lastUpdate);
  }

  String toString(){
    return json.encode([this.rateType.index.toString(),this.lastUpdate.toString()]);
  }

  fromString(String listValues){
    List jsonObject = json.decode(listValues);
    this.rateType = RateType.values[int.parse(jsonObject[0])];
    this.lastUpdate = DateTime.parse(jsonObject[1]);
    //print(this.pathKey+':'+this.rateType.toString()+','+this.lastUpdate.toString());
  }
}