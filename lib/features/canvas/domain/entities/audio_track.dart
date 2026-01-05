enum AudioMarkerKind { marker, phoneme, viseme }

class AudioMarker {
  const AudioMarker({
    required this.timeMs,
    required this.label,
    this.kind = AudioMarkerKind.marker,
  });

  final int timeMs;
  final String label;
  final AudioMarkerKind kind;
}

class AudioTrack {
  const AudioTrack({
    required this.id,
    required this.name,
    required this.source,
    this.offsetMs = 0,
    this.gain = 1.0,
    this.isMuted = false,
    this.markers = const <AudioMarker>[],
  });

  final String id;
  final String name;
  final String source;
  final int offsetMs;
  final double gain;
  final bool isMuted;
  final List<AudioMarker> markers;

  AudioTrack copyWith({
    String? id,
    String? name,
    String? source,
    int? offsetMs,
    double? gain,
    bool? isMuted,
    List<AudioMarker>? markers,
  }) {
    return AudioTrack(
      id: id ?? this.id,
      name: name ?? this.name,
      source: source ?? this.source,
      offsetMs: offsetMs ?? this.offsetMs,
      gain: gain ?? this.gain,
      isMuted: isMuted ?? this.isMuted,
      markers: markers ?? this.markers,
    );
  }
}
