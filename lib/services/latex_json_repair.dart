class LatexJsonRepair {
  static final List<String> _latexCommands = [
    'alpha',
    'beta',
    'gamma',
    'delta',
    'epsilon',
    'varepsilon',
    'zeta',
    'eta',
    'theta',
    'vartheta',
    'iota',
    'kappa',
    'lambda',
    'mu',
    'nu',
    'xi',
    'pi',
    'rho',
    'sigma',
    'tau',
    'upsilon',
    'phi',
    'varphi',
    'chi',
    'psi',
    'omega',
    'Gamma',
    'Delta',
    'Theta',
    'Lambda',
    'Xi',
    'Pi',
    'Sigma',
    'Upsilon',
    'Phi',
    'Psi',
    'Omega',
    'frac',
    'sqrt',
    'times',
    'cdot',
    'pm',
    'mp',
    'le',
    'ge',
    'neq',
    'approx',
    'infty',
    'sum',
    'prod',
    'int',
    'oint',
    'sin',
    'cos',
    'tan',
    'log',
    'ln',
    'exp',
    'left',
    'right',
    'cdots',
    'ldots',
    'dots',
    'text',
    'hat',
    'bar',
    'tilde',
    'top',
    'det',
    'operatorname',
    'wedge',
    'vee',
    'neg',
    'max',
    'min',
  ];

  static String repair(String input) {
    final buffer = StringBuffer();
    bool inString = false;
    int i = 0;

    while (i < input.length) {
      final ch = input[i];

      // Track whether we are inside a quoted JSON string.
      if (ch == '"') {
        final escaped = i > 0 && input[i - 1] == r'\';
        if (!escaped) {
          inString = !inString;
        }
        buffer.write(ch);
        i++;
        continue;
      }

      if (inString && ch == r'\') {
        final next = i + 1 < input.length ? input[i + 1] : '';

        // IMPORTANT FIX:
        // If this is already an escaped backslash (\\), keep both characters
        // and skip both so we do NOT re-process the second slash.
        if (next == r'\') {
          buffer.write(r'\\');
          i += 2;
          continue;
        }

        final rest = input.substring(i + 1);

        // Repair known LaTeX commands first.
        bool matchedLatexCommand = false;
        for (final cmd in _latexCommands) {
          if (rest.startsWith(cmd) &&
              (rest.length == cmd.length ||
                  !RegExp(r'[A-Za-z]').hasMatch(rest[cmd.length]))) {
            buffer.write(r'\\');
            matchedLatexCommand = true;
            break;
          }
        }

        if (matchedLatexCommand) {
          i++; // consume only the current slash
          continue;
        }

        // Repair LaTeX delimiters like \( \) \[ \]
        if (next == '(' || next == ')' || next == '[' || next == ']') {
          buffer.write(r'\\');
          i++;
          continue;
        }

        // Keep valid JSON escapes unchanged.
        const validJsonEscapes = ['"', '/', 'b', 'f', 'n', 'r', 't', 'u'];
        if (validJsonEscapes.contains(next)) {
          buffer.write(ch);
          i++;
          continue;
        }

        // Generic fallback: if a single backslash is followed by a letter,
        // treat it as a likely LaTeX-style command and escape it.
        if (RegExp(r'[A-Za-z]').hasMatch(next)) {
          buffer.write(r'\\');
          i++;
          continue;
        }
      }

      buffer.write(ch);
      i++;
    }

    return buffer.toString();
  }
}
