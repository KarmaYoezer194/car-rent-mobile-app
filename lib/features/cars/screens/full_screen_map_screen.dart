import 'package:flutter/material.dart';

import '../../../widgets/osm_map_view.dart';

/// A single pin, full-screen, for a clearer look than a small embedded map
/// allows — reached via the expand button on Car Details' pickup map.
class FullScreenMapScreen extends StatelessWidget {
  const FullScreenMapScreen({super.key, required this.title, required this.pin});

  final String title;
  final MapPin pin;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: OsmMapView(center: pin, zoom: 16),
    );
  }
}
