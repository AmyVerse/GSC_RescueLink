import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF7F2EC);
    const ink = Color(0xFF2B1E1A);
    const accent = Color(0xFF7A3E2E);

    final theme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 44,
          fontWeight: FontWeight.w800,
          height: 1.05,
          color: ink,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: ink,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF4A3B36),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RescueLink',
      theme: theme,
      initialRoute: '/',
      routes: {
        '/': (_) => const LiveArchivePage(),
        '/map': (_) => const MapPage(),
      },
    );
  }
}

/// Shared map page for both mobile and web.
///
/// Web: make sure `web/index.html` includes the Google Maps JS API script.
/// Android/iOS: set the platform API keys (manifest / Info.plist).
class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
      ),
      body: const _LiveMap(),
    );
  }
}

class _LiveMap extends StatefulWidget {
  const _LiveMap();

  @override
  State<_LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<_LiveMap> {
  GoogleMapController? _controller;
  bool _locating = false;

  static const _initialCamera = CameraPosition(
    target: LatLng(23.181500, 79.986400),
    zoom: 12,
  );

  LatLng? _me;

  @override
  void initState() {
    super.initState();
    _tryLocate();
  }

  Future<void> _tryLocate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are off. Please enable GPS/location.')),
          );
        }
        return;
      }

      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
        }
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission permanently denied. Enable it in system settings.')),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final me = LatLng(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _me = me);
      } else {
        _me = me;
      }
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      const Marker(
        markerId: MarkerId('incident-8194'),
        position: LatLng(23.181500, 79.986400),
        infoWindow: InfoWindow(title: 'Incident #8194'),
      ),
      if (_me != null)
        Marker(
          markerId: const MarkerId('me'),
          position: _me!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
    };

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: _initialCamera,
          onMapCreated: (c) => _controller = c,
          myLocationEnabled: _me != null,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          markers: markers,
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'locate',
            onPressed: _tryLocate,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'LOCATING…' : 'MY LOCATION'),
          ),
        ),
      ],
    );
  }
}

class LiveArchivePage extends StatefulWidget {
  const LiveArchivePage({super.key});

  @override
  State<LiveArchivePage> createState() => _LiveArchivePageState();
}

class _LiveArchivePageState extends State<LiveArchivePage> {
  int _tabIndex = 1; // MAP, FEED, ABOUT, ADMIN

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 980;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        index: _tabIndex,
                        onChanged: (i) => setState(() => _tabIndex = i),
                      ),
                      const SizedBox(height: 44),
                      if (isWide)
                        const _HeaderRow()
                      else
                        const _HeaderColumn(),
                      const SizedBox(height: 18),
                      const Divider(height: 1, color: Color(0xFFE3D8D0)),
                      const SizedBox(height: 18),
                      Expanded(
                        child: _Body(
                          tabIndex: _tabIndex,
                          isWide: isWide,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 18,
              right: 18,
              child: _SosButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SOS pressed (wireframe)')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('MAP')),
          ButtonSegment(value: 1, label: Text('FEED')),
          ButtonSegment(value: 2, label: Text('ABOUT')),
          ButtonSegment(value: 3, label: Text('ADMIN')),
        ],
        selected: {index},
        onSelectionChanged: (set) {
          final selected = set.first;
          if (kIsWeb && selected == 0) {
            Navigator.of(context).pushNamed('/map');
            return;
          }
          onChanged(selected);
        },
        showSelectedIcon: false,
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }
}

class _SosButton extends StatelessWidget {
  const _SosButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7A3E2E);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 6,
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('EMERGENCY', style: TextStyle(fontSize: 10, letterSpacing: 1.1)),
          SizedBox(height: 4),
          Text('SOS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Archive', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 10),
              Text(
                'REAL-TIME TACTICAL EVENT STREAM',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF947F75),
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
        const _IncidentStat(count: 9, label: 'INCIDENTS\nCONNECTED'),
      ],
    );
  }
}

class _HeaderColumn extends StatelessWidget {
  const _HeaderColumn();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Live Archive', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 10),
        Text(
          'REAL-TIME TACTICAL EVENT STREAM',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFF947F75),
                letterSpacing: 2.8,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerRight,
          child: _IncidentStat(count: 9, label: 'INCIDENTS\nCONNECTED'),
        ),
      ],
    );
  }
}

class _IncidentStat extends StatelessWidget {
  const _IncidentStat({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2B1E1A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.right,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF63A9A2),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.tabIndex, required this.isWide});

  final int tabIndex;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    // MAP tab renders an embedded map; other tabs keep the current wireframe.
    if (tabIndex == 0) {
      return _EmbeddedMap(isWide: isWide);
    }

    if (!isWide) {
      return ListView(
        children: const [
          _ReportPanel(),
          SizedBox(height: 16),
          _IncidentCard(
            latLng: '23.181500, 79.986400',
            incidentId: '#8194',
            category: 'Other',
            time: '4/9/2026,\n1:46:46 PM',
            title: 'Incident Reported',
            summaryLines: [
              'Audio transcription…',
              'Severity: Medium',
              'Tags: …',
            ],
          ),
          SizedBox(height: 16),
          _IncidentCard(
            latLng: '37.421998, -122.084000',
            incidentId: '#8193',
            category: 'Biothreat',
            time: '4/9/2026,\n1:31:12 PM',
            title: 'Mass Contagion Event – Biothreat Outbreak',
            summaryLines: [
              "Mass contagion event reported with over 50,000 individuals confirmed infected by an unknown 'zombie' pathogen, including the reporting party. Immediate danger presents as widespread…",
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(
          flex: 3,
          child: _FeedList(),
        ),
        SizedBox(width: 18),
        Expanded(
          flex: 2,
          child: _ReportPanel(),
        ),
      ],
    );
  }
}

class _EmbeddedMap extends StatelessWidget {
  const _EmbeddedMap({required this.isWide});

  final bool isWide;

  static const _initialCamera = CameraPosition(
    target: LatLng(23.181500, 79.986400),
    zoom: 12,
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Map View',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 2.8,
                        color: const Color(0xFF947F75),
                      ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pushNamed('/map'),
                child: const Text('OPEN FULL MAP'),
              )
            ],
          )
        else
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/map'),
              child: const Text('OPEN FULL MAP'),
            ),
          ),
        const SizedBox(height: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
              markers: {
                const Marker(
                  markerId: MarkerId('incident-8194'),
                  position: LatLng(23.181500, 79.986400),
                  infoWindow: InfoWindow(title: 'Incident #8194'),
                ),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FeedList extends StatelessWidget {
  const _FeedList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        _IncidentCard(
          latLng: '23.181500, 79.986400',
          incidentId: '#8194',
          category: 'Other',
          time: '4/9/2026,\n1:46:46 PM',
          title: 'Incident Reported',
          summaryLines: [
            'Audio transcription…',
            'Severity: Medium',
            'Tags: …',
          ],
          primaryActionText: 'TRACK INCIDENT',
          secondaryActionText: 'VIEW UPDATES',
        ),
        SizedBox(height: 18),
        _IncidentCard(
          latLng: '37.421998, -122.084000',
          incidentId: '#8193',
          category: 'Biothreat',
          time: '4/9/2026,\n1:31:12 PM',
          title: 'Mass Contagion Event – Biothreat Outbreak',
          summaryLines: [
            "Mass contagion event reported with over 50,000 individuals confirmed infected by an unknown 'zombie' pathogen, including the reporting party. Immediate danger presents as widespread…",
          ],
          footerLinkText: 'READ FULL BRIEF →',
        ),
      ],
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel();

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'DEPLOY NEW SIGNAL',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: const Color(0xFFB09B91),
                    letterSpacing: 2.8,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 12),
            const _ReportComposer(),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted (wireframe)')),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7A3E2E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'REPORT INCIDENT',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportComposer extends StatelessWidget {
  const _ReportComposer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Describe the incident…',
              filled: true,
              fillColor: const Color(0xFFF1EBE5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE3D8D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE3D8D0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 52,
          width: 52,
          child: OutlinedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Voice input (wireframe)')),
              );
            },
            style: OutlinedButton.styleFrom(
              backgroundColor: const Color(0xFFF1EBE5),
              side: const BorderSide(color: Color(0xFFE3D8D0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Icon(Icons.mic, color: Color(0xFF6B5A54)),
          ),
        ),
      ],
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.latLng,
    required this.incidentId,
    required this.category,
    required this.time,
    required this.title,
    required this.summaryLines,
    this.primaryActionText,
    this.secondaryActionText,
    this.footerLinkText,
  });

  final String latLng;
  final String incidentId;
  final String category;
  final String time;
  final String title;
  final List<String> summaryLines;
  final String? primaryActionText;
  final String? secondaryActionText;
  final String? footerLinkText;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFF7A3E2E)),
                const SizedBox(width: 6),
                Text(
                  latLng,
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 1.4,
                    color: Color(0xFF7A6A64),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Meta(label: 'INCIDENT ID', value: incidentId),
                      const SizedBox(height: 14),
                      _Meta(label: 'CATEGORY', value: category),
                      const SizedBox(height: 14),
                      _Meta(label: 'TIME', value: time),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          color: Color(0xFF2B1E1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final line in summaryLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(line, style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      const SizedBox(height: 12),
                      if (primaryActionText != null || secondaryActionText != null)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            if (primaryActionText != null)
                              FilledButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$primaryActionText (wireframe)')),
                                  );
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3C2B26),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  primaryActionText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            if (secondaryActionText != null)
                              OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$secondaryActionText (wireframe)')),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                  side: const BorderSide(color: Color(0xFFE3D8D0)),
                                  foregroundColor: const Color(0xFF3C2B26),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  secondaryActionText!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (footerLinkText != null) ...[
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$footerLinkText (wireframe)')),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF7A3E2E),
                            padding: EdgeInsets.zero,
                          ),
                          child: Text(
                            footerLinkText!,
                            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 2.6,
            color: Color(0xFFC3B2AA),
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2B1E1A),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF8F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6DDD6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
