import 'package:evil_space/pixel_alphabet.dart';

enum PixelTone {
  none,
  acute,
  grave,
  hook,
  tilde,
  dot,
}

class PixelGlyph {
  const PixelGlyph({
    required this.matrix,
    this.tone = PixelTone.none,
  });

  final List<List<int>> matrix;
  final PixelTone tone;

  int get width => matrix.isEmpty ? 0 : matrix.first.length;
  int get height => matrix.length;
  int get topRows => tone == PixelTone.none || tone == PixelTone.dot ? 0 : 2;
  int get bottomRows => tone == PixelTone.dot ? 1 : 0;
}

class PixelGlyphResolver {
  PixelGlyphResolver._();

  static const Map<String, (String, PixelTone)> _vietnameseTones = {
    'À': ('A', PixelTone.grave),
    'Á': ('A', PixelTone.acute),
    'Ả': ('A', PixelTone.hook),
    'Ã': ('A', PixelTone.tilde),
    'Ạ': ('A', PixelTone.dot),
    'Ằ': ('Ă', PixelTone.grave),
    'Ắ': ('Ă', PixelTone.acute),
    'Ẳ': ('Ă', PixelTone.hook),
    'Ẵ': ('Ă', PixelTone.tilde),
    'Ặ': ('Ă', PixelTone.dot),
    'Ầ': ('Â', PixelTone.grave),
    'Ấ': ('Â', PixelTone.acute),
    'Ẩ': ('Â', PixelTone.hook),
    'Ẫ': ('Â', PixelTone.tilde),
    'Ậ': ('Â', PixelTone.dot),
    'È': ('E', PixelTone.grave),
    'É': ('E', PixelTone.acute),
    'Ẻ': ('E', PixelTone.hook),
    'Ẽ': ('E', PixelTone.tilde),
    'Ẹ': ('E', PixelTone.dot),
    'Ề': ('Ê', PixelTone.grave),
    'Ế': ('Ê', PixelTone.acute),
    'Ể': ('Ê', PixelTone.hook),
    'Ễ': ('Ê', PixelTone.tilde),
    'Ệ': ('Ê', PixelTone.dot),
    'Ì': ('I', PixelTone.grave),
    'Í': ('I', PixelTone.acute),
    'Ỉ': ('I', PixelTone.hook),
    'Ĩ': ('I', PixelTone.tilde),
    'Ị': ('I', PixelTone.dot),
    'Ò': ('O', PixelTone.grave),
    'Ó': ('O', PixelTone.acute),
    'Ỏ': ('O', PixelTone.hook),
    'Õ': ('O', PixelTone.tilde),
    'Ọ': ('O', PixelTone.dot),
    'Ồ': ('Ô', PixelTone.grave),
    'Ố': ('Ô', PixelTone.acute),
    'Ổ': ('Ô', PixelTone.hook),
    'Ỗ': ('Ô', PixelTone.tilde),
    'Ộ': ('Ô', PixelTone.dot),
    'Ờ': ('Ơ', PixelTone.grave),
    'Ớ': ('Ơ', PixelTone.acute),
    'Ở': ('Ơ', PixelTone.hook),
    'Ỡ': ('Ơ', PixelTone.tilde),
    'Ợ': ('Ơ', PixelTone.dot),
    'Ù': ('U', PixelTone.grave),
    'Ú': ('U', PixelTone.acute),
    'Ủ': ('U', PixelTone.hook),
    'Ũ': ('U', PixelTone.tilde),
    'Ụ': ('U', PixelTone.dot),
    'Ừ': ('Ư', PixelTone.grave),
    'Ứ': ('Ư', PixelTone.acute),
    'Ử': ('Ư', PixelTone.hook),
    'Ữ': ('Ư', PixelTone.tilde),
    'Ự': ('Ư', PixelTone.dot),
    'Ỳ': ('Y', PixelTone.grave),
    'Ý': ('Y', PixelTone.acute),
    'Ỷ': ('Y', PixelTone.hook),
    'Ỹ': ('Y', PixelTone.tilde),
    'Ỵ': ('Y', PixelTone.dot),
  };

  static PixelGlyph? resolve(String character) {
    if (character.isEmpty || character == ' ') {
      return null;
    }

    final char = character.toUpperCase();
    final toneEntry = _vietnameseTones[char];
    if (toneEntry != null) {
      final matrix = PixelAlphabet.letters[toneEntry.$1];
      if (matrix == null) {
        return null;
      }
      return PixelGlyph(matrix: matrix, tone: toneEntry.$2);
    }

    final matrix = PixelAlphabet.letters[char];
    if (matrix == null) {
      return null;
    }
    return PixelGlyph(matrix: matrix);
  }
}
