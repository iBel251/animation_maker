enum ObjectKeyChannel {
  position,
  rotation,
  scale,
  opacity,
  visibility,
  strokeWidth,
  strokeColor,
  fillColor;

  static Set<ObjectKeyChannel> get all =>
      Set<ObjectKeyChannel>.unmodifiable(values.toSet());
}

const Set<ObjectKeyChannel> kAllObjectKeyChannels = <ObjectKeyChannel>{
  ObjectKeyChannel.position,
  ObjectKeyChannel.rotation,
  ObjectKeyChannel.scale,
  ObjectKeyChannel.opacity,
  ObjectKeyChannel.visibility,
  ObjectKeyChannel.strokeWidth,
  ObjectKeyChannel.strokeColor,
  ObjectKeyChannel.fillColor,
};
