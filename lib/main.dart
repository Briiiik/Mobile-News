import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'; // Pour Android
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart'; // Pour iOS
import 'package:html/parser.dart' as parser; // Pour le scraping
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'database_helper.dart';


void main() => runApp(NewsApp());

class NewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile News',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light, // Thème clair par défaut
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark, // Thème sombre
      ),
      home: NewsPage(),
      debugShowCheckedModeBanner: false, // Désactive la bannière "debug"
    );
  }
}

class NewsPage extends StatefulWidget {
  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  // En haut de la classe
  final FlutterTts flutterTts = FlutterTts();

  Future<void> _speakArticle(Map article) async {
    await flutterTts.stop(); // Arrête toute lecture en cours
    
    final textToRead = [
      article['title'],
      article['description'] ?? '',
      if (article['content'] != null) article['content'],
    ].where((text) => text != null && text.isNotEmpty).join(". ");

    if (textToRead.isNotEmpty) {
      await flutterTts.setLanguage('fr-FR');
      await flutterTts.speak(textToRead);
    }
  }

  Future<void> _stopSpeaking() async {
    await flutterTts.stop();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final String apiKey = '00e79c1304e94839ac703ee4b0ccf4fe';
  final String apiUrl = 'https://newsapi.org/v2/top-headlines?country=us';
  List articles = [];
  List likedArticles = [];
  List scrapedArticlesAntilla = [];
  List scrapedArticlesRci = [];
  List scrapedArticlesRciObseque = [];
  List scrapedArticlesRciSecondHalf = [];
  bool isLoading = true;
  String _searchText = '';
  bool _isDarkTheme = false;

  @override
  void initState() {
    super.initState();
    _loadThemePreference().then((value) {
      setState(() {
        _isDarkTheme = value;
      });
    });
    fetchNews(); // Charge les articles depuis l'API
    scrapeArticles(); // Scrape les articles depuis Antilla
    scrapeArticlesRci(); // Scrape les articles depuis Rci
    scrapeArticlesRciObseque(); // Scrape les articles depuis Rci
    scrapeArticlesRciSecondHalf(); // Scrape les articles depuis Rci (deuxième moitié)
    _loadLikedArticles(); // Charge les articles likés au démarrage
  }

  // Charge les articles depuis l'API
  Future<void> fetchNews() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl&apiKey=$apiKey'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          articles = data['articles'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load news: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError(e.toString());
    }
  }

  // Scrape les articles depuis une page web (Antilla)
  Future<void> scrapeArticles() async {
    try {
      final response = await http.get(Uri.parse('https://antilla-martinique.com/?s='));
      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // Sélectionner tous les articles
        final articles = document.querySelectorAll('article.l-post');

        setState(() {
          scrapedArticlesAntilla = articles.map((article) {
            // Extraire le lien <a> contenant le titre et l'URL
            final linkElement = article.querySelector('div.media a.image-link');
            final title = linkElement?.attributes['title'] ?? 'No title';
            final url = linkElement?.attributes['href'] ?? '';

            // Extraire l'image (si présente)
            final imageElement = linkElement?.querySelector('span');
            final imageUrl = imageElement?.attributes['data-bgsrc'] ?? '';

            return {
              'image': imageUrl,
              'title': title,
              'url': url,
            };
          }).toList();
        });
      } else {
        print('Failed to load web page: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during scraping: $e');
    }
  }

  Future<void> scrapeArticlesRciObseque() async {
    final baseUrl = 'https://rci.fm/martinique/avis-d-obseques?populate=';
    final totalPages = 10; // Limitez à 10 pages pour le débogage
    List<Map<String, String>> allArticles = [];

    for (int page = 1; page <= totalPages; page++) {
      final url = page == 1 ? baseUrl : '$baseUrl&pg=$page';
      print('Scraping page $page: $url');

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final document = parser.parse(response.body);

          // Sélectionner tous les articles
          final articles = document.querySelectorAll('div.col-lg-6.col-md-6.col-sm-12.col-xs-12.aviso');
          print('Nombre d\'articles trouvés sur la page $page : ${articles.length}');

          final pageArticles = articles.map((article) {
            List<Map<String, String>> articlesInPlace = [];

            // Parcourir les 5 articles (place_1 à place_5)
            for (int place = 1; place <= 5; place++) {
              final div = 'div.place_$place';
              final linkElement = article.querySelector('$div div.d-none.d-md-block div.funeral-show div.funeral-box div.info span a.noa');

              if (linkElement != null) {
                final title = linkElement.text?.trim() ?? 'No title';
                final url = linkElement.attributes['href'] ?? '';

                // Ajouter le préfixe "https://rci.fm/" si l'URL est relative
                final fullUrl = url.startsWith('http') ? url : 'https://rci.fm$url';

                // Extraire l'image (si présente)
                final imageElement = article.querySelector('$div div.d-none.d-md-block div.funeral-show div.funeral-box div.image img');
                final imageUrl = imageElement?.attributes['src'] ?? '';

                articlesInPlace.add({
                  'image': imageUrl,
                  'title': title,
                  'url': fullUrl,
                });
              }
            }

            return articlesInPlace;
          }).expand((articles) => articles).toList(); // Aplatir la liste des articles

          allArticles.addAll(pageArticles);
        } else {
          print('Failed to load page $page: ${response.statusCode}');
        }
      } catch (e) {
        print('Error during scraping page $page: $e');
      }
    }

    // Afficher les articles scrapés dans les logs
    print('Articles RCI scrapés : ${allArticles.length}');
    allArticles.forEach((article) {
      print('Titre : ${article['title']}');
      print('URL : ${article['url']}');
      print('Image : ${article['image']}');
    });

    setState(() {
      scrapedArticlesRciObseque = allArticles;
    });
  }

  Future<void> scrapeArticlesRciSecondHalf() async {
    final baseUrl = 'https://rci.fm/martinique/avis-d-obseques?populate=';
    final totalPages = 10; // Limitez à 10 pages pour le débogage
    List<Map<String, String>> allArticles = [];

    for (int page = 1; page <= totalPages; page++) {
      final url = page == 1 ? baseUrl : '$baseUrl&pg=$page';
      print('Scraping page $page: $url');

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final document = parser.parse(response.body);

          // Sélectionner tous les articles de la deuxième partie
          final articles = document.querySelectorAll('div.colonne-droite.col-lg-6.col-md-6.col-sm-12.col-xs-12');
          print('Nombre d\'articles trouvés sur la page $page : ${articles.length}');

          for (var article in articles) {
            // Sélectionner tous les liens des articles dans cette div
            final linkElements = article.querySelectorAll('div.d-none.d-md-block div.funeral-show div.funeral-box div.info span a.noa');

            for (var linkElement in linkElements) {
              final title = linkElement.text?.trim() ?? 'No title';
              final url = linkElement.attributes['href'] ?? '';

              // Ajouter le préfixe "https://rci.fm/" si l'URL est relative
              final fullUrl = url.startsWith('http') ? url : 'https://rci.fm$url';

              // Extraire l'image (si présente)
              final imageElement = linkElement.parent?.parent?.parent?.querySelector('div.image img');
              final imageUrl = imageElement?.attributes['src'] ?? '';

              allArticles.add({
                'image': imageUrl,
                'title': title,
                'url': fullUrl,
              });
            }
          }
        } else {
          print('Failed to load page $page: ${response.statusCode}');
        }
      } catch (e) {
        print('Error during scraping page $page: $e');
      }
    }

    // Afficher les articles scrapés dans les logs
    print('Articles RCI (deuxième partie) scrapés : ${allArticles.length}');
    allArticles.forEach((article) {
      print('Titre : ${article['title']}');
      print('URL : ${article['url']}');
      print('Image : ${article['image']}');
    });

    setState(() {
      scrapedArticlesRciSecondHalf = allArticles;
    });
  }

  Future<void> scrapeArticlesRci() async {
    final baseUrl = 'https://rci.fm/martinique/infos/toutes-les-infos';
    final totalPages = 10; // Limitez à 10 pages pour le débogage
    List<Map<String, String>> allArticles = [];

    for (int page = 1; page <= totalPages; page++) {
      final url = page == 1 ? baseUrl : '$baseUrl?pg=$page';
      print('Scraping page $page: $url');

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final document = parser.parse(response.body);

          // Sélectionner tous les articles
          final articles = document.querySelectorAll('div.row');
          print('Nombre d\'articles trouvés sur la page $page : ${articles.length}');

          for (var article in articles) {
            // Sélectionner tous les liens des articles dans cette div
            final linkElements = article.querySelectorAll('div.col-lg-6  div.node--type-article article.post-show a.noa');

            for (var linkElement in linkElements) {
              final titleHope = linkElement.querySelector('div.data h3');
              final title = titleHope?.text?.trim() ?? 'No title';

              final url = linkElement.attributes['href'] ?? '';

              // Ajouter le préfixe "https://rci.fm/" si l'URL est relative
              final fullUrl = url.startsWith('http') ? url : 'https://rci.fm$url';

              // Extraire l'image (si présente)
              final imageElement = linkElement.querySelector('div.video-ratio img');
              final imageUrl = imageElement?.attributes['src'] ?? '';

              // Vérifier si l'article existe déjà dans la liste
              final isDuplicate = allArticles.any((a) => a['url'] == fullUrl);
              if (!isDuplicate) {
                allArticles.add({
                  'image': imageUrl,
                  'title': title,
                  'url': fullUrl,
                });
              }
            }
          }
        } else {
          print('Failed to load page $page: ${response.statusCode}');
        }
      } catch (e) {
        print('Error during scraping page $page: $e');
      }
    }
    // Afficher les articles scrapés dans les logs
    print('Articles RCI (deuxième partie) scrapés : ${allArticles.length}');
    allArticles.forEach((article) {
      print('Titre : ${article['title']}');
      print('URL : ${article['url']}');
      print('Image : ${article['image']}');
    });

    setState(() {
      scrapedArticlesRci = allArticles;
    });
  }

  // Sauvegarde les articles likés dans SharedPreferences
  Future<void> _saveLikedArticles() async {
    final prefs = await SharedPreferences.getInstance();
    final likedArticlesJson = likedArticles.map((article) => jsonEncode(article)).toList();
    await prefs.setStringList('likedArticles', likedArticlesJson);
  }

  void _updateSearchText(String text) {
    setState(() {
      _searchText = text;
    });
  }

  // Charger les articles likés depuis SQLite
  Future<void> _loadLikedArticles() async {
    final likedArticlesFromDb = await _dbHelper.getLikedArticles();
    setState(() {
      likedArticles = List<Map<String, dynamic>>.from(likedArticlesFromDb);
    });
  }

  // Ajouter ou supprimer un article liké
  void _toggleLikeArticle(Map article) async {
    final isLiked = likedArticles.any((a) => a['url'] == article['url']);

    if (isLiked) {
      await _dbHelper.deleteArticle(article['url']);
      setState(() {
        likedArticles.removeWhere((a) => a['url'] == article['url']);
      });
    } else {
      await _dbHelper.insertArticle({
        'title': article['title'],
        'description': article['description'],
        'url': article['url'],
        'image': article['urlToImage'] ?? article['image'],
      });
      setState(() {
        likedArticles.add(article);
      });
    }
  }

  // Sauvegarder la préférence de thème
  Future<void> _saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }

  // Charger la préférence de thème
  Future<bool> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isDarkTheme') ?? false;
  }

  // Basculer entre les thèmes
  void _toggleTheme(bool isDark) {
    setState(() {
      _isDarkTheme = isDark;
    });
    _saveThemePreference(isDark);
  }

  @override
  Widget build(BuildContext context) {
    // Filtrer les articles de l'API en fonction de _searchText
    final filteredApiArticles = _searchText.isEmpty
        ? articles
        : articles.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final description = article['description']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText) || description.contains(searchText);
          }).toList();

    // Filtrer les articles scrapés en fonction de _searchText
    final filteredScrapedArticlesAntilla = _searchText.isEmpty
        ? scrapedArticlesAntilla
        : scrapedArticlesAntilla.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText);
          }).toList();

    final filteredScrapedArticlesRci = _searchText.isEmpty
        ? scrapedArticlesRci
        : scrapedArticlesRci.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText);
          }).toList();

    final filteredScrapedArticlesRciObseque = _searchText.isEmpty
        ? scrapedArticlesRciObseque
        : scrapedArticlesRciObseque.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText);
          }).toList();

    final filteredScrapedArticlesRciSecondHalf = _searchText.isEmpty
        ? scrapedArticlesRciSecondHalf
        : scrapedArticlesRciSecondHalf.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText);
          }).toList();

    return MaterialApp(
      theme: _isDarkTheme ? ThemeData.dark() : ThemeData.light(),
      home: Scaffold(
        appBar: AppBar(
          title: Text('Mobile News'),
          actions: [
            Switch(
              value: _isDarkTheme,
              onChanged: _toggleTheme,
            ),
          ],
        ),
        body: DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Mobile News'),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'News API'),
                  Tab(text: 'Antilla Articles'),
                  Tab(text: 'RCI Articles'),
                  Tab(text: "Avis d'obsèque"),
                  Tab(text: "Avis d'obsèque"),
                ],
              ),
            ),
            body: Column(
              children: [
                SearchSection(
                  onSearchTextChanged: _updateSearchText,
                  onViewLikedArticles: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LikedArticlesPage(
                          likedArticles: likedArticles,
                          onUnlikeArticle: _toggleLikeArticle,
                        ),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // Articles de l'API
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : filteredApiArticles.isEmpty
                              ? Center(child: Text('Aucun résultat trouvé'))
                              : ListView.builder(
                                  itemCount: filteredApiArticles.length,
                                  itemBuilder: (context, index) {
                                    final article = filteredApiArticles[index];
                                    final isLiked = likedArticles.any((a) => a['url'] == article['url']);

                                    return Card(
                                      margin: EdgeInsets.all(8.0),
                                      color: Theme.of(context).cardColor,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ArticleDetailPage(article: article),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (article['urlToImage'] != null)
                                              Image.network(
                                                article['urlToImage'],
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  // Bouton Like existant
                                                  IconButton(
                                                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                                                    onPressed: () => _toggleLikeArticle(article),
                                                  ),
                                                  // Nouveau bouton TTS
                                                  IconButton(
                                                    icon: Icon(Icons.volume_up),
                                                    onPressed: () => _speakArticle(article),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              child: Text(
                                                article['description'] ?? 'No description',
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                      // Articles scrapés depuis Antilla
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : filteredScrapedArticlesAntilla.isEmpty
                              ? Center(child: Text('Aucun résultat trouvé'))
                              : ListView.builder(
                                  itemCount: filteredScrapedArticlesAntilla.length,
                                  itemBuilder: (context, index) {
                                    final article = filteredScrapedArticlesAntilla[index];
                                    final isLiked = likedArticles.contains(article);

                                    return Card(
                                      margin: EdgeInsets.all(8.0),
                                      color: Theme.of(context).cardColor,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ArticleDetailPage(article: article),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (article['image'].isNotEmpty)
                                              Image.network(
                                                article['image'],
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  // Bouton Like existant
                                                  IconButton(
                                                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                                                    onPressed: () => _toggleLikeArticle(article),
                                                  ),
                                                  // Nouveau bouton TTS
                                                  IconButton(
                                                    icon: Icon(Icons.volume_up),
                                                    onPressed: () => _speakArticle(article),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              child: Text(
                                                article['url'] ?? 'No URL',
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                      // Articles scrapés depuis RCI
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : filteredScrapedArticlesRci.isEmpty
                              ? Center(child: Text('Aucun résultat trouvé'))
                              : ListView.builder(
                                  itemCount: filteredScrapedArticlesRci.length,
                                  itemBuilder: (context, index) {
                                    final article = filteredScrapedArticlesRci[index];
                                    final isLiked = likedArticles.contains(article);

                                    return Card(
                                      margin: EdgeInsets.all(8.0),
                                      color: Theme.of(context).cardColor,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ArticleDetailPage(article: article),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (article['image'].isNotEmpty)
                                              Image.network(
                                                article['image'],
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  // Bouton Like existant
                                                  IconButton(
                                                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                                                    onPressed: () => _toggleLikeArticle(article),
                                                  ),
                                                  // Nouveau bouton TTS
                                                  IconButton(
                                                    icon: Icon(Icons.volume_up),
                                                    onPressed: () => _speakArticle(article),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              child: Text(
                                                article['url'] ?? 'No URL',
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                      // Articles scrapés depuis RCI (première partie)
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : filteredScrapedArticlesRciObseque.isEmpty
                              ? Center(child: Text('Aucun résultat trouvé'))
                              : ListView.builder(
                                  itemCount: filteredScrapedArticlesRciObseque.length,
                                  itemBuilder: (context, index) {
                                    final article = filteredScrapedArticlesRciObseque[index];
                                    final isLiked = likedArticles.contains(article);

                                    return Card(
                                      margin: EdgeInsets.all(8.0),
                                      color: Theme.of(context).cardColor,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ArticleDetailPage(article: article),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (article['image'].isNotEmpty)
                                              Image.network(
                                                article['image'],
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Row(
                                                  children: [
                                                    // Bouton Like existant
                                                    IconButton(
                                                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                                                      onPressed: () => _toggleLikeArticle(article),
                                                    ),
                                                    // Nouveau bouton TTS
                                                    IconButton(
                                                      icon: Icon(Icons.volume_up),
                                                      onPressed: () => _speakArticle(article),
                                                    ),
                                                  ],
                                                )
                                              ),
                                            
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              child: Text(
                                                article['url'] ?? 'No URL',
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                      // Articles scrapés depuis RCI (deuxième partie)
                      isLoading
                          ? Center(child: CircularProgressIndicator())
                          : filteredScrapedArticlesRciSecondHalf.isEmpty
                              ? Center(child: Text('Aucun résultat trouvé'))
                              : ListView.builder(
                                  itemCount: filteredScrapedArticlesRciSecondHalf.length,
                                  itemBuilder: (context, index) {
                                    final article = filteredScrapedArticlesRciSecondHalf[index];
                                    final isLiked = likedArticles.contains(article);

                                    return Card(
                                      margin: EdgeInsets.all(8.0),
                                      color: Theme.of(context).cardColor,
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ArticleDetailPage(article: article),
                                            ),
                                          );
                                        },
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            if (article['image'].isNotEmpty)
                                              Image.network(
                                                article['image'],
                                                height: 150,
                                                fit: BoxFit.cover,
                                              ),
                                            Padding(
                                              padding: EdgeInsets.all(8.0),
                                              child: Row(
                                                children: [
                                                  // Bouton Like existant
                                                  IconButton(
                                                    icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
                                                    onPressed: () => _toggleLikeArticle(article),
                                                  ),
                                                  // Nouveau bouton TTS
                                                  IconButton(
                                                    icon: Icon(Icons.volume_up),
                                                    onPressed: () => _speakArticle(article),
                                                  ),
                                                ],
                                              )
                                            ),
                                            Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                              child: Text(
                                                article['url'] ?? 'No URL',
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }
}

class ArticleDetailPage extends StatefulWidget {
  final Map article;

  ArticleDetailPage({required this.article});
  
  @override
  _ArticleDetailPageState createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  late final FlutterTts flutterTts;
  bool isSpeaking = false;

  @override
  void initState() {
    super.initState();
    flutterTts = FlutterTts();
    _setupTts();
  }

  Future<void> _setupTts() async {
    await flutterTts.setLanguage('fr-FR');
    flutterTts.setCompletionHandler(() {
      setState(() => isSpeaking = false);
    });
  }

  Future<void> _toggleSpeaking() async {
    if (isSpeaking) {
      await flutterTts.stop();
      setState(() => isSpeaking = false);
    } else {
      final text = [
        widget.article['title'],
        widget.article['description'] ?? '',
        if (widget.article['content'] != null) widget.article['content'],
      ].join(". ");
      
      await flutterTts.speak(text);
      setState(() => isSpeaking = true);
    }
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.article['title'] ?? 'Article'),
        actions: [
          IconButton(
            icon: Icon(isSpeaking ? Icons.stop : Icons.volume_up),
            onPressed: _toggleSpeaking,
          ),
        ],
      ),
      body: WebView(
        url: widget.article['url'] ?? '',
        title: widget.article['title'] ?? 'Article',
      ),
    );
  }
}

class SearchSection extends StatefulWidget {
  final Function(String) onSearchTextChanged;
  final VoidCallback onViewLikedArticles;

  SearchSection({required this.onSearchTextChanged, required this.onViewLikedArticles});

  @override
  _SearchSectionState createState() => _SearchSectionState();
}

class _SearchSectionState extends State<SearchSection> {
  String _searchText = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(74, 182, 182, 182),
      height: 90,
      padding: EdgeInsets.fromLTRB(5, 5, 0, 0),
      child: Column(
        children: [
          Row(children: [
            Expanded(
                child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(224, 0, 0, 0),
                    offset: Offset(0, 3),
                    blurRadius: 2,
                  )
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 5),
                child: TextField(
                onChanged: widget.onSearchTextChanged,
                decoration: InputDecoration(
                  hintText: "Search...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                        BorderSide(color: const Color.fromARGB(255, 20, 189, 130)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: const Color.fromARGB(0, 0, 0, 0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.blueAccent),
                  ),
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: TextStyle(color: Colors.white),
              ),
              )
            )),
            SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: widget.onViewLikedArticles,
            )
          ])
        ],
      ),
    );
  }
}

class WebView extends StatefulWidget {
  final String url;
  final String title;

  WebView({required this.url, required this.title});

  @override
  _WebViewPageState createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();

    // Configuration du contrôleur WebView
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // Correction ici
      ..loadRequest(Uri.parse(widget.url));

    // Configuration spécifique pour Android
    if (_controller.platform is AndroidWebViewController) {
      (_controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: WebViewWidget(controller: _controller), // Utilisation de WebViewWidget
    );
  }
}

class LikedArticlesPage extends StatefulWidget {
  final List likedArticles;
  final Function(Map) onUnlikeArticle;

  LikedArticlesPage({
    required this.likedArticles,
    required this.onUnlikeArticle,
  });

  @override
  _LikedArticlesPageState createState() => _LikedArticlesPageState();
}

class _LikedArticlesPageState extends State<LikedArticlesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Liked Articles"),
      ),
      body: widget.likedArticles.isEmpty
          ? Center(child: Text("No liked articles yet!"))
          : ListView.builder(
              itemCount: widget.likedArticles.length,
              itemBuilder: (context, index) {
                final article = widget.likedArticles[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ArticleDetailPage(article: article),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (article['image'] != null && article['image'].isNotEmpty)
                          Image.network(
                            article['image'],
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            article['title'] ?? 'No title',
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                          child: Text(
                            article['description'] ?? article['url'] ?? 'No description',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.favorite, color: Colors.red),
                          onPressed: () {
                            widget.onUnlikeArticle(article);
                            setState(() {
                              widget.likedArticles.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}