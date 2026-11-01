import 'package:animeav1_plugin/js_literal.dart';
import 'package:test/test.dart';

Object? parse(String s) => parseJsValue(s, 0);

void main() {
  test('claves sin comillas, números y anidados', () {
    expect(parse('{id:1,title:"x",n:-2.5,list:[1,2,{a:null}],ok:true}'),
        {'id': 1, 'title': 'x', 'n': -2.5, 'list': [1, 2, {'a': null}], 'ok': true});
  });

  test('void 0, !0, !1 y undefined', () {
    expect(parse('{a:void 0,b:!0,c:!1,d:undefined}'), {'a': null, 'b': true, 'c': false, 'd': null});
  });

  test('cadenas con escapes, llaves y comillas', () {
    expect(parse(r'{s:"a\"b\c\né {x:1}, y"}'), {'s': 'a"b\c\né {x:1}, y'});
  });

  test('new Date devuelve el texto', () {
    expect(parse('{d:new Date("2026-11-01")}'), {'d': '2026-11-01'});
  });

  test('función autoinvocada con objetos compartidos (formato del catálogo)', () {
    final v = parse('(function(a,b){a.id=1;a.name="TV Anime";b.id=5;'
        'return {type:"data",data:{results:[{category:a},{category:b},{category:a}]}}}({},{}))');
    final results = ((v as Map)['data'] as Map)['results'] as List;
    expect((results[0] as Map)['category'], {'id': 1, 'name': 'TV Anime'});
    expect((results[1] as Map)['category'], {'id': 5});
    expect(results[0]['category'], same(results[2]['category']));
  });

  test('la asignación puede ir después de usar la variable', () {
    final v = parse('(function(a){return {x:a}}({}))');
    expect(v, {'x': {}});
  });

  test('para al terminar el valor y deja el resto', () {
    const src = 'data: [null,{type:"data"}], form: null';
    final start = src.indexOf('[');
    expect(parseJsValue(src, start), [null, {'type': 'data'}]);
  });

  test('entrada inválida lanza JsParseException', () {
    expect(() => parse('{a:desconocida}'), throwsA(isA<JsParseException>()));
    expect(() => parse('{a:"sin cerrar'), throwsA(isA<JsParseException>()));
  });
}
