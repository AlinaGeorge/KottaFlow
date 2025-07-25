import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

void main() => runApp(TrafficMapApp());

class TrafficMapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Traffic Map',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: TrafficHomePage(),
    );
  }
}

class TrafficHomePage extends StatefulWidget {
  @override
  _TrafficHomePageState createState() => _TrafficHomePageState();
}

class _TrafficHomePageState extends State<TrafficHomePage> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  String startPoint = '';
  String endPoint = '';
  final _formKey = GlobalKey<FormState>();
  Timer? _timer;

  final List<Map<String, dynamic>> junctionCoordinates = [
    {"name": "Junction A", "lat": 10.9975, "lng": 76.0047},
    {"name": "Junction B", "lat": 11.0002, "lng": 76.0025},
    {"name": "Junction C", "lat": 10.9990, "lng": 76.0080},
  ];

  @override
  void initState() {
    super.initState();
    fetchJunctionData();
    fetchRoute();
    _timer = Timer.periodic(Duration(seconds: 5), (_) => fetchJunctionData());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchJunctionData() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/status/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final junctions = data['junctions'];
      Set<Marker> updatedMarkers = {};

      for (var j in junctions) {
        final coord = junctionCoordinates.firstWhere(
          (e) => e["name"] == j["name"],
          orElse: () => {},
        );
        if (coord.isEmpty) continue;

        final String signal = j["signal"];
        final String alert = j["alert"];
        final int count = j["vehicle_count"];
        final Color markerColor = signal == "RED"
            ? Colors.red
            : signal == "YELLOW"
                ? Colors.orange
                : Colors.green;

        updatedMarkers.add(
          Marker(
            markerId: MarkerId(j["name"]),
            position: LatLng(coord["lat"], coord["lng"]),
            infoWindow: InfoWindow(
              title: j["name"],
              snippet: "Vehicles: $count | $alert",
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              markerColor == Colors.red
                  ? BitmapDescriptor.hueRed
                  : markerColor == Colors.orange
                      ? BitmapDescriptor.hueOrange
                      : BitmapDescriptor.hueGreen,
            ),
          ),
        );
      }

      setState(() => _markers = updatedMarkers);
    }
  }

  Future<void> fetchRoute() async {
    final response = await http.get(Uri.parse('http://127.0.0.1:8000/api/route/get/'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        startPoint = data['start'];
        endPoint = data['end'];
      });
    }
  }

  Future<void> submitRoute() async {
    final response = await http.post(
      Uri.parse('http://127.0.0.1:8000/api/route/set/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"start": startPoint, "end": endPoint}),
    );

    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Route submitted successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit route')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Smart Traffic Map")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: "Start Location"),
                    onChanged: (value) => startPoint = value,
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: "End Location"),
                    onChanged: (value) => endPoint = value,
                  ),
                  SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: submitRoute,
                    child: Text("Submit Route"),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(10.9985, 76.0050),
                zoom: 14.0,
              ),
              markers: _markers,
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }
}
