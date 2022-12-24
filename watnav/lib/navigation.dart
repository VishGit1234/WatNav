import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:tuple/tuple.dart';
import 'package:watnav/paths.dart';
import 'package:watnav/nodeInfo.dart';

class IsolateModel {
  IsolateModel(
      this.origin,
      this.dest,
      this.startLevel,
      this.endLevel,
      this.paths,
      this.adjacencyMatrix,
      this.indoorWeight,
      this.nodeLevels,
      this.nodeInfo,
      this.isOriginNode,
      this.isDestNode);
  bool isOriginNode;
  bool isDestNode;
  LatLng origin;
  LatLng dest;
  int startLevel;
  int endLevel;
  Map<LatLng, List<LatLng>> adjacencyMatrix;
  List<Tuple2<Map<String, int>, Map<String, List<LatLng>>>> paths;
  double indoorWeight;
  Map<LatLng, int> nodeLevels;
  Map<LatLng, List<String>> nodeInfo;
}

class Navigation {
  NodeInfo nodeInfo = NodeInfo();
  Map<LatLng, List<LatLng>> _adjMatrix = {};
  Paths pathObj = Paths();
  final Map<LatLng, int> _levelsNodes = {};
  Map<LatLng, List<LatLng>> _generateAdjacencyMatrix(
      List<Tuple2<Map<String, int>, Map<String, List<LatLng>>>> paths) {
    Map<LatLng, List<LatLng>> matrix = {};
    for (int pathNum = 0; pathNum < paths.length; pathNum++) {
      List<LatLng> path = paths[pathNum].item2['path']!;
      for (int nodeNum = 0; nodeNum < path.length; nodeNum++) {
        matrix[path[nodeNum]] = [];
        _levelsNodes[path[nodeNum]] = paths[pathNum].item1['level']!;
      }
    }
    for (int pathNum = 0; pathNum < paths.length; pathNum++) {
      List<LatLng> path = paths[pathNum].item2['path']!;
      for (int nodeNum = 0; nodeNum < path.length; nodeNum++) {
        if (nodeNum == 0) {
          matrix[path[nodeNum]]?.add(path[nodeNum + 1]);
          //debugPrint(path[nodeNum + 1].latitude.toString());
        } else if (nodeNum == path.length - 1) {
          matrix[path[nodeNum]]?.add(path[nodeNum - 1]);
          //debugPrint(path[nodeNum - 1].latitude.toString());
        } else {
          matrix[path[nodeNum]]?.add(path[nodeNum + 1]);
          matrix[path[nodeNum]]?.add(path[nodeNum - 1]);
          //debugPrint(path[nodeNum + 1].latitude.toString());
        }
      }
    }
    return matrix;
  }

  Map<LatLng, List<LatLng>> adjMatrix() {
    return _adjMatrix;
  }

  Map<LatLng, int> levelsNodes() {
    return _levelsNodes;
  }

  int test(IsolateModel model) {
    var startLevel = model.startLevel;
    var endLevel = model.endLevel;
    LatLng curPos = model.origin;
    var dest = model.dest;
    int _count = 0;
    for (int i = 0; i < 10000000; i++) {
      _count++;
      if ((_count % 100) == 0) {
        debugPrint("compute: " + _count.toString());
      }
    }
    return _count;
  }

  void setup() {
    var allPaths = pathObj.allPaths();
    _adjMatrix = _generateAdjacencyMatrix(allPaths);
  }
}
