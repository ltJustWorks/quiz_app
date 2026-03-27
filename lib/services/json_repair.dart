class JsonRepair {
  static String repair(String input) {
    var s = input;

    // Remove outer fenced code blocks like ```json ... ```
    s = _stripCodeFences(s);

    // Normalize smart quotes to regular quotes
    s = s
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll("‘", "'")
        .replaceAll("’", "'");

    // Remove stray closing parenthesis after a JSON string before comma/brace/bracket
    // Example: "text": "hello")
    s = s.replaceAllMapped(RegExp(r'"(\s*)\)(\s*[,}\]])'), (m) => '"${m[2]}');

    // Remove trailing commas before } or ]
    s = s.replaceAllMapped(RegExp(r',(\s*[}\]])'), (m) => m[1]!);

    return s;
  }

  static String _stripCodeFences(String input) {
    var s = input.trim();

    if (s.startsWith('```json')) {
      s = s.substring(7).trimLeft();
    } else if (s.startsWith('```')) {
      s = s.substring(3).trimLeft();
    }

    if (s.endsWith('```')) {
      s = s.substring(0, s.length - 3).trimRight();
    }

    return s;
  }
}
