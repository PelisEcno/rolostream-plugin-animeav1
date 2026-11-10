import 'package:rolostream_core/rolostream_core.dart' as core;
import 'animeav1_plugin.dart' as raw;

class AnimeAV1Source implements core.SourcePlugin {
  AnimeAV1Source([raw.AnimeAV1Plugin? plugin]) : _plugin = plugin ?? raw.AnimeAV1Plugin();

  final raw.AnimeAV1Plugin _plugin;

  @override
  String get id => 'animeav1';

  @override
  String get name => 'AnimeAV1';

  @override
  String? get iconAsset => null;

  @override
  String slugFromUrl(String url) {
    final segs = Uri.tryParse(url)?.pathSegments.where((s) => s.isNotEmpty).toList() ?? [];
    if (segs.length >= 2 && segs.first == 'media') return segs[1];
    return segs.isEmpty ? url : segs.last;
  }

  @override
  ({String slug, int numero})? parseEpisodeUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final m = RegExp(r'^/media/([^/]+)/(\d+)/?$').firstMatch(path);
    if (m == null) return null;
    return (slug: m.group(1)!, numero: int.parse(m.group(2)!));
  }

  @override
  Future<List<core.AnimeResult>> search(String query) async => [
        for (final a in await _plugin.search(query))
          core.AnimeResult(nombre: a.nombre, url: a.url, imagen: a.imagen),
      ];

  @override
  Future<core.AnimeDetail> getAnime(String slug) async {
    final d = await _plugin.getAnime(slug);
    return core.AnimeDetail(
      titulo: d.titulo,
      sinopsis: d.sinopsis,
      imagen: d.imagen,
      estado: d.estado,
      generos: d.generos,
      episodios: [
        for (final e in d.episodios)
          core.Episode(numero: e.numero, url: e.url, titulo: e.titulo),
      ],
    );
  }

  @override
  Future<List<core.VideoServer>> getServers(String slug, int numero) async => [
        for (final s in await _plugin.getServers(slug, numero))
          core.VideoServer(nombre: s.nombre, url: s.url),
      ];

  @override
  Future<List<core.RecentEpisode>> getLatestEpisodes() async => [
        for (final e in await _plugin.getLatestEpisodes())
          core.RecentEpisode(titulo: e.titulo, url: e.url, imagen: e.imagen, fecha: e.fecha),
      ];

  @override
  Future<List<core.RecentSerie>> getRecentSeries() async => [
        for (final s in await _plugin.getRecentSeries())
          core.RecentSerie(titulo: s.titulo, url: s.url, imagen: s.imagen),
      ];

  @override
  Future<List<core.AiringAnime>> getAiringAnimes({int page = 1}) async => [
        for (final a in await _plugin.getAiringAnimes(page: page))
          core.AiringAnime(
              titulo: a.titulo, url: a.url, imagen: a.imagen, tipo: a.tipo, anio: a.anio),
      ];

  @override
  Future<List<core.FilterAnime>> getAnimesByFilter({
    String genero = 'false',
    String fecha = 'false',
    String letra = 'false',
    String categoria = 'false',
    int page = 1,
  }) async =>
      [
        for (final a in await _plugin.getAnimesByFilter(
          genero: genero,
          fecha: fecha,
          letra: letra,
          categoria: categoria,
          page: page,
        ))
          core.FilterAnime(
              titulo: a.titulo, url: a.url, imagen: a.imagen, tipo: a.tipo, anio: a.anio),
      ];

  @override
  core.FilterOptions get filterOptions => _filterOptions;
}

const _generos = <core.FilterOption>[
  core.FilterOption('accion', 'Acción'),
  core.FilterOption('aventura', 'Aventura'),
  core.FilterOption('ciencia-ficcion', 'Ciencia Ficción'),
  core.FilterOption('comedia', 'Comedia'),
  core.FilterOption('deportes', 'Deportes'),
  core.FilterOption('drama', 'Drama'),
  core.FilterOption('fantasia', 'Fantasía'),
  core.FilterOption('misterio', 'Misterio'),
  core.FilterOption('recuentos-de-la-vida', 'Recuentos de la Vida'),
  core.FilterOption('romance', 'Romance'),
  core.FilterOption('seinen', 'Seinen'),
  core.FilterOption('shoujo', 'Shoujo'),
  core.FilterOption('shounen', 'Shounen'),
  core.FilterOption('sobrenatural', 'Sobrenatural'),
  core.FilterOption('suspenso', 'Suspenso'),
  core.FilterOption('terror', 'Terror'),
  core.FilterOption('antropomorfico', 'Antropomórfico'),
  core.FilterOption('artes-marciales', 'Artes Marciales'),
  core.FilterOption('carreras', 'Carreras'),
  core.FilterOption('detectives', 'Detectives'),
  core.FilterOption('ecchi', 'Ecchi'),
  core.FilterOption('elenco-adulto', 'Elenco Adulto'),
  core.FilterOption('escolares', 'Escolares'),
  core.FilterOption('espacial', 'Espacial'),
  core.FilterOption('gore', 'Gore'),
  core.FilterOption('gourmet', 'Gourmet'),
  core.FilterOption('harem', 'Harem'),
  core.FilterOption('historico', 'Histórico'),
  core.FilterOption('idols-hombre', 'Idols (Hombre)'),
  core.FilterOption('idols-mujer', 'Idols (Mujer)'),
  core.FilterOption('infantil', 'Infantil'),
  core.FilterOption('isekai', 'Isekai'),
  core.FilterOption('josei', 'Josei'),
  core.FilterOption('juegos-estrategia', 'Juegos Estrategia'),
  core.FilterOption('mahou-shoujo', 'Mahou Shoujo'),
  core.FilterOption('mecha', 'Mecha'),
  core.FilterOption('militar', 'Militar'),
  core.FilterOption('mitologia', 'Mitología'),
  core.FilterOption('musica', 'Música'),
  core.FilterOption('parodia', 'Parodia'),
  core.FilterOption('psicologico', 'Psicológico'),
  core.FilterOption('samurai', 'Samurai'),
  core.FilterOption('shoujo-ai', 'Shoujo Ai'),
  core.FilterOption('shounen-ai', 'Shounen Ai'),
  core.FilterOption('superpoderes', 'Superpoderes'),
  core.FilterOption('vampiros', 'Vampiros'),
];

const _categorias = <core.FilterOption>[
  core.FilterOption('tv-anime', 'TV Anime'),
  core.FilterOption('pelicula', 'Película'),
  core.FilterOption('ova', 'OVA'),
  core.FilterOption('especial', 'Especial'),
  core.FilterOption('ona', 'ONA'),
];

final _letras = <core.FilterOption>[
  const core.FilterOption('0-9', '0-9'),
  for (final c in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) core.FilterOption(c, c),
];

final _filterOptions = core.FilterOptions(
  generos: _generos,
  anios: [for (var y = 2026; y >= 1990; y--) core.FilterOption('$y', '$y')],
  letras: _letras,
  categorias: _categorias,
);
