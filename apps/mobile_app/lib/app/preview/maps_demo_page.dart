import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;

import '../../features/dog_walks/data/dog_walks_repository.dart';
import '../../features/dog_walks/domain/walk_session.dart';
import '../../features/local_activities/data/local_activities_repository.dart';
import '../../features/local_activities/domain/local_activity.dart';
import '../../features/location/domain/coordinates.dart';
import '../../features/marketplace/data/marketplace_repository.dart';
import '../../features/marketplace/domain/marketplace_listing.dart';

/// Isolated demo harness for the "gestione mappe" foundations
/// (docs/maps/): renders a real flutter_map with seed data from all three
/// features - local activities, a marketplace listing, a dog-walk route -
/// so the domain/data layer is visibly working without touching
/// app/shell/home_shell_page.dart or replacing the ComingSoon stubs in
/// activities_page.dart/local_events_page.dart. Reachable only by
/// navigating to AppRouter.mapsDemo directly (e.g. from a widget test or
/// by typing the URL on web) - no button in the real app links here.
class MapsDemoPage extends StatefulWidget {
  const MapsDemoPage({super.key});

  @override
  State<MapsDemoPage> createState() => _MapsDemoPageState();
}

class _MapsDemoPageState extends State<MapsDemoPage> {
  static const _demoOwnerId = 'demo-user';
  static const latlong.LatLng _milanCenter = latlong.LatLng(45.4642, 9.1900);

  late final Future<_MapsDemoData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MapsDemoData> _loadData() async {
    final activities = await LocalActivitiesRepository().loadActiveActivities();
    final listings = await MarketplaceRepository().loadActiveListings();
    final walks = await DogWalksRepository().loadWalks(_demoOwnerId);
    return _MapsDemoData(activities: activities, listings: listings, walks: walks);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Maps demo (fondamenta)')),
      body: FutureBuilder<_MapsDemoData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return Column(
            children: [
              Expanded(
                child: FlutterMap(
                  options: const MapOptions(initialCenter: _milanCenter, initialZoom: 12.5),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.vetapp.mobile_app',
                    ),
                    PolylineLayer(polylines: _walkPolylines(data.walks)),
                    MarkerLayer(markers: [
                      ..._activityMarkers(data.activities),
                      ..._listingMarkers(data.listings),
                    ]),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
              _Legend(
                activityCount: data.activities.length,
                listingCount: data.listings.length,
                walkCount: data.walks.where((w) => w.status == WalkStatus.completed).length,
              ),
            ],
          );
        },
      ),
    );
  }

  List<Polyline> _walkPolylines(List<WalkSession> walks) {
    return walks
        .where((walk) => walk.route.length >= 2)
        .map(
          (walk) => Polyline(
            points: walk.route.map((point) => _toLatLng(point.coordinates)).toList(),
            color: Colors.deepOrange,
            strokeWidth: 4,
          ),
        )
        .toList();
  }

  List<Marker> _activityMarkers(List<LocalActivity> activities) {
    return activities
        .map(
          (activity) => Marker(
            point: _toLatLng(activity.location),
            width: 36,
            height: 36,
            child: Tooltip(
              message: activity.title,
              child: Icon(
                activity.kind == LocalActivityKind.event ? Icons.event : Icons.medical_services,
                color: Colors.blue,
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _listingMarkers(List<MarketplaceListing> listings) {
    return listings
        .map(
          (listing) => Marker(
            point: _toLatLng(listing.location),
            width: 36,
            height: 36,
            child: Tooltip(
              message: '${listing.title} (posizione approssimata)',
              child: const Icon(Icons.storefront, color: Colors.amber),
            ),
          ),
        )
        .toList();
  }

  latlong.LatLng _toLatLng(Coordinates coordinates) {
    return latlong.LatLng(coordinates.latitude, coordinates.longitude);
  }
}

class _MapsDemoData {
  const _MapsDemoData({required this.activities, required this.listings, required this.walks});

  final List<LocalActivity> activities;
  final List<MarketplaceListing> listings;
  final List<WalkSession> walks;
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.activityCount,
    required this.listingCount,
    required this.walkCount,
  });

  final int activityCount;
  final int listingCount;
  final int walkCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text('🔵 Attività/eventi: $activityCount'),
          Text('🟡 Annunci mercatino: $listingCount'),
          Text('🟠 Percorsi passeggiata: $walkCount'),
        ],
      ),
    );
  }
}
