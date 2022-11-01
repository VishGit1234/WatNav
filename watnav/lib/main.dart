import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import 'package:watnav/buildings.dart';
import 'package:location/location.dart';
import 'package:watnav/navigation.dart';
import 'package:flutter/foundation.dart';

void main() async {
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
  @override
  void initState() {
    super.initState();
    navigation.setup();
    _getLocation();
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

  static double indoorWeight = 0.8;
  final MapController mapController = MapControllerImpl();
  final Location location = Location();
  bool circularProgressIndicatorVisibility = false;
  Buildings buildings = Buildings();
  double lat = 43.4723;
  double lng = -80.5449;
  LatLng point = LatLng(43.4723, -80.5449);
  LatLng dest = LatLng(0, 0);
  late String startBuilding;
  int startFloor = -200;
  int endFloor = -200;
  LatLng origin = LatLng(0, 0);
  List<LatLng> path = [];
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
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options:
              MapOptions(center: point, zoom: 16, minZoom: 16, maxZoom: 20),
          children: [
            TileLayer(
              urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
              subdomains: const ['a', 'b', 'c'],
              maxNativeZoom: 19,
              maxZoom: 25,
            ),
            MarkerLayer(
              markers: markers,
            ),
            PolylineLayer(
              polylines: [pathLine],
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
                      matches.addAll(buildings.returnBuildings());
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
                  onSuggestionSelected: (suggestion) {
                    dest = buildings.classrooms[suggestion]!.item1;
                    endFloor = buildings.classrooms[suggestion]!.item3;
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
                              matches.addAll(buildings.returnBuildings());
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
                          onSuggestionSelected: (suggestion) {
                            typeAheadController2.text = suggestion;
                            if (suggestion != groundString) {
                              startFloor =
                                  buildings.classrooms[suggestion]!.item3;
                              origin = buildings.classrooms[suggestion]!.item1;
                            } else {
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
                  typeAheadController.text = groundString;
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
                  Future.delayed(const Duration(milliseconds: 500), () {
                    compute<IsolateModel, List<LatLng>>(
                            getPathIndoor,
                            IsolateModel(
                                origin,
                                dest,
                                startFloor,
                                endFloor,
                                navigation.pathObj.allPaths,
                                navigation.adjMatrix,
                                indoorWeight,
                                navigation.levelsNodes))
                        .then((value) => {
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                //Generate map line
                                setState(() {
                                  pathLine = Polyline(
                                      points: value,
                                      color: Colors.red,
                                      strokeWidth: 3.0);
                                  circularProgressIndicatorVisibility = false;
                                });
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
                  });
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
        )
      ],
    );
  }
}

//Cuz isolates are annoying the return type cannot have lat and lng
List<LatLng> getPathIndoor(IsolateModel model) {
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
  LatLng closestNodeToStartPos = LatLng(0.0, 0.0);
  double endNodeMinDist = double.maxFinite;
  LatLng closestNodeToEndPos = LatLng(0.0, 0.0);
  for (LatLng k in model.adjacencyMatrix.keys) {
    //Check for closest node only if on same level
    if (startLevel == model.nodeLevels[k]) {
      //Get the node that is closest to the starting position
      double tempDist = const Vincenty().distance(k, curPos);
      if (tempDist < startNodeMinDist) {
        startNodeMinDist = tempDist;
        closestNodeToStartPos = k;
      }
    }
    //Check for closest node only if on same level
    if (endLevel == model.nodeLevels[k]) {
      //Get the node that is closest to the starting position
      double tempDist = const Vincenty().distance(k, dest);
      if (tempDist < endNodeMinDist) {
        endNodeMinDist = tempDist;
        closestNodeToEndPos = k;
      }
    }
    //Initialise values in maps for Dijkstra's Algorithm
    distances[k] = double.maxFinite;
    distancesUnweighted[k] = double.maxFinite;
    visited[k] = false;
  }
  //Add your starting position and ending position to the adjacency matrix
  model.adjacencyMatrix[curPos] = [closestNodeToStartPos];
  model.adjacencyMatrix[dest] = [closestNodeToEndPos];
  model.adjacencyMatrix[closestNodeToEndPos]!.add(dest);
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
  }
  return path;
  //return 0;
}
