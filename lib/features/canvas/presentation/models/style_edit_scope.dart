enum StyleEditScope {
  global,
  timeline;

  bool get isGlobal => this == StyleEditScope.global;
  bool get isTimeline => this == StyleEditScope.timeline;
}
