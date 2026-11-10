/// Intérprete mínimo de los literales JavaScript que SvelteKit incrusta en el HTML. No es JSON:
/// claves sin comillas, `void 0`, `!0`, `new Date(...)` y funciones autoinvocadas.
Object? parseJsValue(String source, int start) => _JsParser(source, start).parseValue();

class JsParseException implements Exception {
  final String message;
  final int offset;
  JsParseException(this.message, this.offset);

  @override
  String toString() => 'JsParseException($message @ $offset)';
}

class _JsParser {
  _JsParser(this._s, this._i);

  final String _s;
  int _i;

  /// Pila de ámbitos de las funciones autoinvocadas.
  final List<Map<String, Object?>> _scopes = [];

  Never _fail(String msg) => throw JsParseException(msg, _i);

  void _ws() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x20 || c == 0x0A || c == 0x0D || c == 0x09) {
        _i++;
      } else {
        break;
      }
    }
  }

  bool _peekIs(String text) => _s.startsWith(text, _i);

  void _expect(String ch) {
    _ws();
    if (_i >= _s.length || _s[_i] != ch) _fail("se esperaba '$ch'");
    _i++;
  }

  static bool _isIdentStart(int c) =>
      (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F || c == 0x24;

  static bool _isIdentPart(int c) => _isIdentStart(c) || (c >= 0x30 && c <= 0x39);

  String _ident() {
    final st = _i;
    if (_i >= _s.length || !_isIdentStart(_s.codeUnitAt(_i))) _fail('identificador');
    while (_i < _s.length && _isIdentPart(_s.codeUnitAt(_i))) {
      _i++;
    }
    return _s.substring(st, _i);
  }

  bool _keyword(String word) {
    if (!_peekIs(word)) return false;
    final end = _i + word.length;
    return end >= _s.length || !_isIdentPart(_s.codeUnitAt(end));
  }

  Object? parseValue() {
    _ws();
    if (_i >= _s.length) _fail('fin inesperado');
    final c = _s[_i];
    switch (c) {
      case '{':
        return _object();
      case '[':
        return _array();
      case '"':
      case "'":
        return _string();
      case '(':
        return _paren();
      case '!':
        _i++;
        _ws();
        final n = _number();
        return n == 0; // !0 → true, !1 → false
      case '-':
        return _number();
    }
    final code = c.codeUnitAt(0);
    if (code >= 0x30 && code <= 0x39) return _number();
    if (_isIdentStart(code)) return _identOrKeyword();
    _fail("carácter inesperado '$c'");
  }

  Object? _identOrKeyword() {
    if (_keyword('true')) {
      _i += 4;
      return true;
    }
    if (_keyword('false')) {
      _i += 5;
      return false;
    }
    if (_keyword('null')) {
      _i += 4;
      return null;
    }
    if (_keyword('undefined')) {
      _i += 9;
      return null;
    }
    if (_keyword('NaN')) {
      _i += 3;
      return null;
    }
    if (_keyword('Infinity')) {
      _i += 8;
      return double.infinity;
    }
    if (_keyword('void')) {
      _i += 4;
      parseValue(); // `void 0`
      return null;
    }
    if (_keyword('new')) {
      _i += 3;
      _ws();
      final cls = _ident();
      _expect('(');
      final args = <Object?>[];
      _ws();
      while (_i < _s.length && _s[_i] != ')') {
        args.add(parseValue());
        _ws();
        if (_i < _s.length && _s[_i] == ',') _i++;
        _ws();
      }
      _expect(')');
      // new Date("2026-…") → texto; el resto de clases no se usan.
      return cls == 'Date' && args.isNotEmpty ? args.first : null;
    }
    final name = _ident();
    return _lookup(name);
  }

  Object? _lookup(String name) {
    for (var k = _scopes.length - 1; k >= 0; k--) {
      if (_scopes[k].containsKey(name)) return _scopes[k][name];
    }
    _fail("variable desconocida '$name'");
  }

  num _number() {
    final st = _i;
    if (_s[_i] == '-') _i++;
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      final digit = c >= 0x30 && c <= 0x39;
      if (digit || c == 0x2E || c == 0x65 || c == 0x45 ||
          ((c == 0x2B || c == 0x2D) && (_s[_i - 1] == 'e' || _s[_i - 1] == 'E'))) {
        _i++;
      } else {
        break;
      }
    }
    final n = num.tryParse(_s.substring(st, _i));
    if (n == null) _fail('número inválido');
    return n;
  }

  String _string() {
    final quote = _s[_i++];
    final buf = StringBuffer();
    while (true) {
      if (_i >= _s.length) _fail('cadena sin cerrar');
      final c = _s[_i++];
      if (c == quote) return buf.toString();
      if (c != r'\') {
        buf.write(c);
        continue;
      }
      if (_i >= _s.length) _fail('escape incompleto');
      final e = _s[_i++];
      switch (e) {
        case 'n':
          buf.write('\n');
        case 'r':
          buf.write('\r');
        case 't':
          buf.write('\t');
        case 'b':
          buf.write('\b');
        case 'f':
          buf.write('\f');
        case 'v':
          buf.write('\v');
        case '0':
          buf.write('\u0000');
        case 'x':
          buf.writeCharCode(int.parse(_s.substring(_i, _i + 2), radix: 16));
          _i += 2;
        case 'u':
          if (_s[_i] == '{') {
            final end = _s.indexOf('}', _i);
            buf.writeCharCode(int.parse(_s.substring(_i + 1, end), radix: 16));
            _i = end + 1;
          } else {
            buf.writeCharCode(int.parse(_s.substring(_i, _i + 4), radix: 16));
            _i += 4;
          }
        case '\n':
          break; // continuación de línea
        default:
          buf.write(e); // \" \' \\ \/ …
      }
    }
  }

  List<Object?> _array() {
    _expect('[');
    final out = <Object?>[];
    while (true) {
      _ws();
      if (_i >= _s.length) _fail('arreglo sin cerrar');
      if (_s[_i] == ']') {
        _i++;
        return out;
      }
      if (_s[_i] == ',') {
        _i++;
        out.add(null); // hueco
        continue;
      }
      out.add(parseValue());
      _ws();
      if (_i < _s.length && _s[_i] == ',') _i++;
    }
  }

  Map<String, Object?> _object() {
    _expect('{');
    final out = <String, Object?>{};
    while (true) {
      _ws();
      if (_i >= _s.length) _fail('objeto sin cerrar');
      if (_s[_i] == '}') {
        _i++;
        return out;
      }
      final String key;
      final c = _s[_i];
      if (c == '"' || c == "'") {
        key = _string();
      } else if (_isIdentStart(c.codeUnitAt(0))) {
        key = _ident();
      } else {
        key = _number().toString();
      }
      _expect(':');
      out[key] = parseValue();
      _ws();
      if (_i < _s.length && _s[_i] == ',') _i++;
    }
  }

  Object? _paren() {
    _expect('(');
    _ws();
    final Object? value;
    if (_keyword('function')) {
      value = _iife();
    } else {
      value = parseValue();
    }
    _expect(')');
    return value;
  }

  Object? _iife() {
    _i += 'function'.length;
    _ws();
    if (_i < _s.length && _isIdentStart(_s.codeUnitAt(_i))) _ident(); // nombre opcional
    _expect('(');
    final params = <String>[];
    _ws();
    while (_i < _s.length && _s[_i] != ')') {
      params.add(_ident());
      _ws();
      if (_s[_i] == ',') _i++;
      _ws();
    }
    _expect(')');
    _expect('{');
    final bodyStart = _i;
    _skipBlock(); // los argumentos van DESPUÉS del cuerpo: se leen primero
    // _i queda justo tras el '}' del cuerpo.
    _ws();
    final args = <Object?>[];
    if (_i < _s.length && _s[_i] == '(') {
      _i++;
      _ws();
      while (_i < _s.length && _s[_i] != ')') {
        args.add(parseValue());
        _ws();
        if (_i < _s.length && _s[_i] == ',') _i++;
        _ws();
      }
      _expect(')');
    }
    final afterCall = _i;

    final scope = <String, Object?>{
      for (var k = 0; k < params.length; k++) params[k]: k < args.length ? args[k] : null,
    };
    _scopes.add(scope);
    _i = bodyStart;
    final result = _body();
    _scopes.removeLast();
    _i = afterCall;
    return result;
  }

  Object? _body() {
    while (true) {
      _ws();
      if (_i >= _s.length) _fail('cuerpo sin cerrar');
      if (_s[_i] == ';') {
        _i++;
        continue;
      }
      if (_keyword('return')) {
        _i += 'return'.length;
        final v = parseValue();
        return v;
      }
      if (_s[_i] == '}') return null;
      final name = _ident();
      Object? target = _lookup(name);
      String? lastKey;
      Map<String, Object?>? holder;
      while (_i < _s.length && _s[_i] == '.') {
        _i++;
        final prop = _ident();
        if (target is! Map<String, Object?>) _fail('asignación a algo que no es objeto');
        holder = target;
        lastKey = prop;
        target = holder[prop];
      }
      _ws();
      if (_i >= _s.length || _s[_i] != '=') _fail('se esperaba "="');
      _i++;
      final value = parseValue();
      if (holder == null || lastKey == null) _fail('asignación inválida');
      holder[lastKey] = value;
    }
  }

  void _skipBlock() {
    var depth = 1;
    while (_i < _s.length) {
      final c = _s[_i];
      if (c == '"' || c == "'") {
        _string();
        continue;
      }
      if (c == '{') depth++;
      if (c == '}') {
        depth--;
        if (depth == 0) {
          _i++;
          return;
        }
      }
      _i++;
    }
    _fail('bloque sin cerrar');
  }
}
