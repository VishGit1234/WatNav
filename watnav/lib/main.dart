import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:watnav/buildings.dart';
import 'package:watnav/api_key.dart';
import 'package:location/location.dart';
import 'package:watnav/navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: WatNav(),
    );
  }
}

class WatNav extends StatefulWidget {
  const WatNav({super.key});

  @override
  State<WatNav> createState() => _WatNavState();
}

class _WatNavState extends State<WatNav> {
  late LatLng curPos;
  Navigation navigation = Navigation();
  List<String> classroomList = [];
  @override
  void initState() {
    super.initState();
    navigation.setup();
    _getLocation();
    _getClassroomList();
  }

  void _getClassroomList() async {
    var uri = Uri.http(requestUrl, "/classrooms");
    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200) {
        for (var val in jsonDecode(resp.body)["value"]) {
          classroomList.add(val.toString());
        }
      } else {
        throw Exception("Failed to load classrooms");
      }
    } catch (err) {
      debugPrint("-----> $err");
    }
  }

  Future _getLocation() async {
    Location location = Location();
    var _permissionGranted = await location.hasPermission();
    var _serviceEnabled = await location.serviceEnabled();
    var _loading = true;
    var _highAccuracy = true;
    _highAccuracy =
        await location.changeSettings(accuracy: LocationAccuracy.high);

    if (_permissionGranted != PermissionStatus.granted || !_serviceEnabled) {
      _permissionGranted = await location.requestPermission();
      _serviceEnabled = await location.requestService();
    } else {
      setState(() {
        _serviceEnabled = true;
        _loading = false;
      });
    }
    var _longitude;
    var _latitude;
    try {
      final LocationData currentPosition = await location.getLocation();
      setState(() {
        _longitude = currentPosition.longitude;
        _latitude = currentPosition.latitude;
        curPos = LatLng(_latitude, _longitude);
        _loading = false;
      });
    } on PlatformException catch (err) {
      _loading = false;
      debugPrint("-----> ${err.code}");
    }
  }

  static const double indoorWeight = 1.0;
  final MapController mapController = MapControllerImpl();
  final Location location = Location();
  bool circularProgressIndicatorVisibility = false;
  Buildings buildings = Buildings();
  LatLng dest = LatLng(0, 0);
  late String startBuilding;
  int startFloor = -200;
  int endFloor = -200;
  LatLng origin = LatLng(0, 0);
  double distance = 0.0;
  List<LatLng> path = [];
  bool isOriginNode = false;
  bool isDestNode = false;
  String requestUrl = "20.175.143.102:5000";

  List<Marker> markers = [
    Marker(
        point: LatLng(0, 0),
        builder: (context) {
          return const Icon(Icons.abc);
        }),
    Marker(
        point: LatLng(0, 0),
        builder: (context) {
          return const Icon(Icons.abc);
        })
  ];

  Polyline pathLine = Polyline(points: [], color: Colors.red);
  final TextEditingController typeAheadController = TextEditingController();
  final TextEditingController typeAheadController2 = TextEditingController();
  static const String groundString = "GROUND - CURRENT LOCATION";
  final Uri ATTRIBUTION_URL =
      Uri.parse("https://www.openstreetmap.org/copyright");
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        FlutterMap(
          mapController: mapController,
          options: MapOptions(
            maxBounds: LatLngBounds(
                LatLng(43.47625903088465, -80.56022596513974),
                LatLng(43.46459913399943, -80.53560342017133)),
            center: LatLng(43.4723, -80.5449),
            zoom: 16,
            minZoom: 16,
            maxZoom: 20,
            onTap: (pos, loc) {
              dest = loc;
              typeAheadController.text = loc.toString();
              endFloor = -200;
              isDestNode = false;
              markers[0] = Marker(
                width: 40,
                height: 40,
                point: dest,
                builder: (context) => const Align(
                  alignment: Alignment.topCenter,
                  child: Icon(
                    Icons.location_on,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          children: [
            TileLayer(
              //urlTemplate: "http://127.0.0.1:870/tile/{z}/{x}/{y}.png",
              urlTemplate:
                  "https://maptiles.p.rapidapi.com/en/map/v1/{z}/{x}/{y}.png?rapidapi-key=$MAP_API_KEY",
              //urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              //subdomains: const ['a', 'b', 'c'],
              maxNativeZoom: 19,
              maxZoom: 25,
            ),
            PolylineLayer(
              saveLayers: false,
              polylines: [pathLine],
            ),
            MarkerLayer(
              markers: markers,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 34.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Card(
                child: TypeAheadField(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: typeAheadController,
                    autofocus: true,
                    style: const TextStyle(fontSize: 15),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.all(16.0),
                      hintText: "Search for a classroom/building",
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  suggestionsCallback: (pattern) {
                    List<String> matches = <String>[];
                    if (pattern.isNotEmpty) {
                      matches.addAll(classroomList);
                      matches.retainWhere((s) {
                        return s.toLowerCase().contains(pattern.toLowerCase());
                      });
                    }
                    return matches;
                  },
                  itemBuilder: (context, sone) {
                    return Card(
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(sone.toString()),
                      ),
                    );
                  },
                  onSuggestionSelected: (suggestion) async {
                    isDestNode = true;
                    var uri = Uri.http(requestUrl, "/classroom/$suggestion");
                    final resp =
                        await http.get(uri).timeout(const Duration(seconds: 3));
                    final decoded = jsonDecode(resp.body)["value"];
                    dest = LatLng(double.parse(decoded[1]["lat"]),
                        double.parse(decoded[1]["lon"]));
                    endFloor = int.parse(decoded[2]);
                    mapController.move(dest, 20);
                    typeAheadController.text = suggestion;
                    //Put marker at destination
                    setState(() {
                      markers[0] = Marker(
                        width: 40,
                        height: 40,
                        point: dest,
                        builder: (context) => const Align(
                          alignment: Alignment.topCenter,
                          child: Icon(
                            Icons.location_on,
                            size: 20,
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        Stack(
          alignment: AlignmentDirectional.topEnd,
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16.0, vertical: 100.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Card(
                        child: TypeAheadField(
                          textFieldConfiguration: TextFieldConfiguration(
                            controller: typeAheadController2,
                            autofocus: true,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.all(16.0),
                              hintText: "Where you at now?",
                              prefixIcon: Icon(Icons.location_on_outlined),
                            ),
                          ),
                          suggestionsCallback: ((pattern) {
                            List<String> matches = <String>[];
                            if (pattern.isNotEmpty) {
                              matches.addAll(classroomList);
                              matches.retainWhere((s) {
                                return s
                                    .toLowerCase()
                                    .contains(pattern.toLowerCase());
                              });
                            }
                            matches.add(groundString);
                            return matches;
                          }),
                          itemBuilder: (context, itemData) {
                            return Card(
                              child: Container(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(itemData.toString())),
                            );
                          },
                          onSuggestionSelected: (suggestion) async {
                            typeAheadController2.text = suggestion;
                            if (suggestion != groundString) {
                              isOriginNode = true;
                              var uri = Uri.http(
                                  requestUrl, "/classroom/$suggestion");
                              final resp = await http
                                  .get(uri)
                                  .timeout(const Duration(seconds: 3));
                              final decoded = jsonDecode(resp.body)["value"];
                              startFloor = int.parse(decoded[2]);
                              //startFloor =
                              //  buildings.classrooms[suggestion]!.item3;
                              origin = LatLng(double.parse(decoded[1]["lat"]),
                                  double.parse(decoded[1]["lon"]));
                            } else {
                              isOriginNode = false;
                              _getLocation();
                              origin = curPos;
                              debugPrint(startFloor.toString());
                              startFloor = -200;
                            }
                            //Put marker at destination
                            setState(() {
                              markers[1] = Marker(
                                width: 40,
                                height: 40,
                                point: origin,
                                builder: (context) => const Icon(
                                  Icons.my_location_rounded,
                                  size: 20,
                                  color: Colors.blue,
                                ),
                              );
                            });
                          },
                        ),
                      )
                    ])),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18.0, vertical: 115.0),
              child: TextButton(
                style: ButtonStyle(
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(300),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
                onPressed: () {
                  typeAheadController2.text = groundString;
                  startBuilding = "GROUND";
                  //-200 = ground
                  startFloor = -200;
                  _getLocation();
                  origin = curPos;
                  setState(() {
                    markers[1] = Marker(
                      width: 40,
                      height: 40,
                      point: origin,
                      builder: (context) => const Icon(
                        Icons.my_location_rounded,
                        size: 20,
                        color: Colors.blue,
                      ),
                    );
                  });
                },
                child: const Icon(Icons.my_location_sharp),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 153.0),
              child: TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(Colors.green),
                  shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
                onPressed: () {
                  if (origin != dest) {
                    path = [];
                    //LatLng temp = LatLng(43.471935837383704, -80.54473026509238);
                    setState(() {
                      circularProgressIndicatorVisibility = true;

                      markers[1] = Marker(
                        width: 40,
                        height: 40,
                        point: origin,
                        builder: (context) => const Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: Colors.blue,
                        ),
                      );
                    });

                    //Delete previous node info markers
                    for (int i = 2; i < markers.length; i++) {
                      markers.removeAt(i);
                    }
                    /*IMPORTANT NOTE
                    The future delayed below contains the code that generates the
                    path (run inside a seperate thread using an isolate spawned
                    with compute). Unforunately since flutter is dumb, there is no
                    support for isolates for web apps, so in the future I have to 
                    implement code to use worker threads for web app version
                    (which means a javascript :( implementation of Dijktra's 
                    algorithm must be made). For now though there will be a slight 
                    freeze when using WEB APP but THIS DOESN'T APPLY TO MOBILE.
                    */
                    final queryParams = {
                      "start_lat": "${origin.latitude}",
                      "start_lon": "${origin.longitude}",
                      "start_level": "$startFloor",
                      "end_lat": "${dest.latitude}",
                      "end_lon": "${dest.longitude}",
                      "end_level": "$endFloor",
                      "indoor_weight": "$indoorWeight"
                    };
                    var uri = Uri.http(requestUrl, "/route", queryParams);
                    print(uri.toString());
                    Marker tempMark;
                    final resp = http
                        .get(uri)
                        .timeout(const Duration(seconds: 3))
                        .then((value) => {
                              //Get path
                              for (var node in jsonDecode(value.body)["path"])
                                {path.add(LatLng(node["lat"], node["lon"]))},
                              //Get stair locations
                              for (var node
                                  in jsonDecode(value.body)["stair_locations"])
                                {
                                  tempMark = Marker(
                                    point: LatLng(node["lat"], node["lon"]),
                                    builder: (context) => const Align(
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.stairs_rounded,
                                        size: 25,
                                      ),
                                    ),
                                  ),
                                  markers.add(tempMark),
                                },
                              //Draw Path
                              setState(() {
                                pathLine = Polyline(
                                    points: path,
                                    color: Colors.red,
                                    strokeWidth: 3.0);
                                circularProgressIndicatorVisibility = false;
                              })
                            });
                    /*
                    Future.delayed(const Duration(milliseconds: 500), () {
                      compute<IsolateModel, Map<double, List<LatLng>>>(
                              getPathIndoor,
                              IsolateModel(
                                  origin,
                                  dest,
                                  startFloor,
                                  endFloor,
                                  navigation.pathObj.allPaths(),
                                  navigation.adjMatrix(),
                                  indoorWeight,
                                  navigation.levelsNodes(),
                                  navigation.nodeInfo.nodeInfo(),
                                  isOriginNode,
                                  isDestNode))
                          .then((value) => {
                                Future.delayed(
                                    const Duration(milliseconds: 500), () {
                                  for (var k in value.keys) {
                                    if (k >= 0) {
                                      distance = k;
                                    }
                                  }
                                  //debugPrint(distance.toString());
                                  path = value[distance]!;
                                  //Generate map line
                                  setState(() {
                                    //Stairs is -1 in map
                                    //Generate stair locations
                                    for (var stairLoc in value[-1.0]!) {
                                      Marker tempMark = Marker(
                                        point: stairLoc,
                                        builder: (context) => const Align(
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.stairs_rounded,
                                            size: 25,
                                          ),
                                        ),
                                      );
                                      markers.add(tempMark);
                                    }
                                    pathLine = Polyline(
                                        points: path,
                                        color: Colors.red,
                                        strokeWidth: 3.0);
                                    circularProgressIndicatorVisibility = false;
                                  });
                                  debugPrint(path[0].latitude.toString());
                                  //Zoom out to show whole route
                                  LatLng routeCenter = LatLng(
                                      origin.latitude +
                                          ((origin.latitude - dest.latitude)
                                                  .abs() *
                                              0.5),
                                      origin.longitude +
                                          ((origin.longitude - dest.longitude)
                                                  .abs() *
                                              0.5));
                                  mapController.move(routeCenter, 17);
                                  /*
                                //Find angle of inital line
                                debugPrint(mapController.rotation.toString());
                                double angleFirstLine = 180 +
                                    radianToDeg(atan2(
                                        value[1].longitude - value[0].longitude,
                                        value[1].latitude - value[0].latitude));
                                mapController.moveAndRotate(temp, 22,
                                    mapController.rotation + angleFirstLine);
                                */
                                })
                              });
                    });*/
                  }
                },
                child: const Text(
                  "Let's GO!!",
                  style: TextStyle(color: Colors.white, fontSize: 30),
                ),
              ),
            ),
          ],
        ),
        Visibility(
          visible: circularProgressIndicatorVisibility,
          child: Center(
            child: Stack(children: [
              SizedBox(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: const DecoratedBox(
                      decoration: BoxDecoration(
                          color: Color.fromARGB(200, 255, 255, 255)))),
              const Center(
                child: SizedBox(
                  height: 150,
                  width: 150,
                  child: CircularProgressIndicator(
                    value: null,
                    color: Color.fromARGB(214, 255, 221, 0),
                    backgroundColor: Colors.black,
                  ),
                ),
              ),
            ]),
          ),
        ),
        Container(
          alignment: Alignment.topCenter,
          width: 250,
          height: 25,
          color: Colors.white,
          child: TextButton(
            onPressed: () async {
              if (!await launchUrl(ATTRIBUTION_URL)) {
                throw 'Could not launch $ATTRIBUTION_URL';
              }
            },
            child: const Text(
              "© OpenStreetMap contributors",
              style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                  fontFamily: "Times New Roman",
                  color: Colors.blue),
            ),
          ),
        )
      ],
    );
  }
}

//Cuz isolates are annoying the return type cannot have lat and lng
Map<double, List<LatLng>> getPathIndoor(IsolateModel model) {
  var startLevel = model.startLevel;
  var endLevel = model.endLevel;
  var curPos = model.origin;
  var dest = model.dest;
  //Initialise distances between source and nodes as infinity
  Map<LatLng, double> distances = {};
  Map<LatLng, double> distancesUnweighted = {};
  //No nodes have been visited yet so the list is initialised as false
  Map<LatLng, bool> visited = {};
  Map<LatLng, LatLng> previousNodes = {};
  //Find closest node to current position
  double startNodeMinDist = double.maxFinite;
  LatLng closestNodeToStartPos = curPos;
  double endNodeMinDist = double.maxFinite;
  LatLng closestNodeToEndPos = dest;
  for (LatLng k in model.adjacencyMatrix.keys) {
    if (!model.isOriginNode) {
      //Check for closest node only if on same level
      if (startLevel == model.nodeLevels[k]) {
        //Get the node that is closest to the starting position
        double tempDist = const Vincenty().distance(k, curPos);
        if (tempDist < startNodeMinDist) {
          startNodeMinDist = tempDist;
          closestNodeToStartPos = k;
        }
      }
    }
    if (!model.isDestNode) {
      //Check for closest node only if on same level
      if (endLevel == model.nodeLevels[k]) {
        //Get the node that is closest to the starting position
        double tempDist = const Vincenty().distance(k, dest);
        if (tempDist < endNodeMinDist) {
          endNodeMinDist = tempDist;
          closestNodeToEndPos = k;
        }
      }
    }
    //Initialise values in maps for Dijkstra's Algorithm
    distances[k] = double.maxFinite;
    distancesUnweighted[k] = double.maxFinite;
    visited[k] = false;
  }
  //Add your starting position and ending position to the adjacency matrix
  if (!model.isOriginNode) {
    model.adjacencyMatrix[curPos] = [closestNodeToStartPos];
  }
  if (!model.isDestNode) {
    model.adjacencyMatrix[dest] = [closestNodeToEndPos];
  }
  //Add distance of end node as infinity and set visited false
  distances[dest] = double.maxFinite;
  visited[dest] = false;
  //CHANGE THE SOURCE (TO DO LATER)
  LatLng src = curPos;
  //The distance from the source to the source is 0
  distances[src] = 0.0;
  distancesUnweighted[src] = 0.0;
  visited[src] = false;

  //Distance path
  double pathDist = 0.0;

  //Get adjacent nodes for source node
  LatLng curNode = LatLng(0, 0);
  List<LatLng> adjacentNodes = [];

  /*
  Once you have found the adjacent nodes for the current node
  Go through the adjacent nodes and identify the adjacent node that has
  not been visited with the shortest distance from the SOURCE NODE
  */
  while (visited.containsValue(false)) {
    double minDist = double.maxFinite - 100;
    LatLng closestNode = LatLng(0, 0);
    for (var k in distances.keys) {
      if (distances[k] == null || visited[k] == null) {
        debugPrint("Error: null value");
      }
      if (distances[k]! < minDist && visited[k]! == false) {
        //debugPrint(minDist.toString());
        minDist = distances[k]!;
        closestNode = k;
      }
    }
    if (closestNode == LatLng(0, 0)) {
      //This means that a path could not be found
      debugPrint("Not sure how this happened but loool!");
      break;
    }
    curNode = closestNode;
    if (closestNode == dest) {
      pathDist = distances[dest]!;
      break;
    }
    visited[closestNode] = true;
    adjacentNodes = model.adjacencyMatrix[curNode]!;
    for (int count = 0; count < adjacentNodes.length; count++) {
      var adjacentNode = adjacentNodes[count];
      //Make sure node has not been visited
      //debugPrint("wh");
      if (visited[adjacentNode] == false) {
        //Distance from adjacent node to SOURCE node
        double alt = ((const Vincenty().distance(curNode, adjacentNode)) +
            distances[curNode]!);
        if (model.nodeLevels[adjacentNode] != -200) {
          alt *= model.indoorWeight;
        }
        //Check if the just calculated distance is less than the
        //distance recorded in the dictionary
        if (alt < distances[adjacentNode]!) {
          distances[adjacentNode] = alt;
          previousNodes[adjacentNode] = curNode;
        }
      }
    }
  }
  List<LatLng> path = [];
  if (previousNodes.isNotEmpty || curNode == src) {
    do {
      //debugPrint(curNode.latitude.toString());
      //debugPrint(curNode.longitude.toString());
      path.insert(0, curNode);
      curNode = previousNodes[curNode]!;
    } while (curNode != src);
    path.insert(0, curPos);
  }
  Map<double, List<LatLng>> emptyDict = {};
  emptyDict[distances[closestNodeToEndPos]!] = path;
  //Generate markers at stair locations
  List<LatLng> stairLocations = [];
  for (int nodeNum = 0; nodeNum < path.length; nodeNum++) {
    if (model.nodeInfo.containsKey(path[nodeNum])) {
      if (model.nodeInfo[path[nodeNum]]![0] == "stair") {
        //Stairs is -1.0
        stairLocations.add(path[nodeNum]);
        nodeNum++;
      }
    }
  }
  //Stairs is -1.0
  emptyDict[-1.0] = stairLocations;

  return emptyDict;
}
