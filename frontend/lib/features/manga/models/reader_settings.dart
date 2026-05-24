enum ReadingMode { vertical, horizontal }

enum ReadingDirection { ltr, rtl }

class ReaderSettings {
  final ReadingMode mode;
  final ReadingDirection direction;
  final bool keepScreenOn;

  const ReaderSettings({
    this.mode = ReadingMode.vertical,
    this.direction = ReadingDirection.ltr,
    this.keepScreenOn = true,
  });
}
