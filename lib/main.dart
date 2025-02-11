import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart'; // Pour Android
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart'; // Pour iOS

void main() => runApp(NewsApp());

class NewsApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile News',
      theme: ThemeData(
        primarySwatch: Colors.blue,
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
  final String apiKey = '00e79c1304e94839ac703ee4b0ccf4fe';
  final String apiUrl = 'https://newsapi.org/v2/top-headlines?country=us';
  List articles = [];
  List likedArticles = [];
  bool isLoading = true;
  String _searchText = '';

  void _updateSearchText(String text) {
    setState(() {
      _searchText = text;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchNews();
  }

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
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List filteredArticles = _searchText.isEmpty
        ? articles // Afficher tous les articles si la recherche est vide
        : articles.where((article) {
            final title = article['title']?.toLowerCase() ?? '';
            final description = article['description']?.toLowerCase() ?? '';
            final searchText = _searchText.trim().toLowerCase();
            return title.contains(searchText) || description.contains(searchText);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Mobile News'),
      ),
      body: Column(
        children: [
          SearchSection(
            onSearchTextChanged: _updateSearchText,
            onViewLikedArticles: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LikedArticlesPage(likedArticles: likedArticles),
                ),
              );
            },
          ),
          isLoading
              ? Expanded(child: Center(child: CircularProgressIndicator()))
              : Expanded(
                  child: ListView.builder(
                    itemCount: filteredArticles.length,
                    itemBuilder: (context, index) {
                      final article = filteredArticles[index];
                      final isLiked = likedArticles.contains(article);
                      return GestureDetector(
                        onTap: () {
                          showArticleDetail(article);
                        },
                        child: Card(
                          margin: EdgeInsets.all(6.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (article['urlToImage'] != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8.0),
                                    child: Image.network(
                                      article['urlToImage'],
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                SizedBox(height: 8),
                                Text(
                                  article['title'] ?? 'No title',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  article['description'] ?? 'No description',
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isLiked
                                            ? Icons.favorite
                                            : Icons.favorite_outline_rounded,
                                        color: Colors.red[800],
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          if (isLiked) {
                                            likedArticles.remove(article);
                                          } else {
                                            likedArticles.add(article);
                                          }
                                        });
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.open_in_new, // Icône pour ouvrir l'article
                                        color: Colors.blue[800],
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        // Ouvrir l'article dans un WebView
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ArticleDetailPage(article: article),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  void showArticleDetail(Map article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(article: article),
      ),
    );
  }
}

class ArticleDetailPage extends StatelessWidget {
  final Map article;

  ArticleDetailPage({required this.article});

  @override
  Widget build(BuildContext context) {
    return WebView(
      url: article['url'] ?? '', // URL de l'article
      title: article['title'] ?? 'Article', // Titre de l'article
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

class LikedArticlesPage extends StatelessWidget {
  final List likedArticles;

  LikedArticlesPage({required this.likedArticles});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Liked Articles"),
      ),
      body: likedArticles.isEmpty
          ? Center(child: Text("No liked articles yet!"))
          : ListView.builder(
              itemCount: likedArticles.length,
              itemBuilder: (context, index) {
                final article = likedArticles[index];
                return ListTile(
                  title: Text(article['title'] ?? 'No title'),
                  subtitle: Text(article['description'] ?? 'No description'),
                );
              },
            ),
    );
  }
}