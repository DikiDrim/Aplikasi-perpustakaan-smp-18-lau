import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/open_url.dart';
import '../models/buku_model.dart';

class BacaBukuScreen extends StatefulWidget {
  final BukuModel buku;

  const BacaBukuScreen({super.key, required this.buku});

  @override
  State<BacaBukuScreen> createState() => _BacaBukuScreenState();
}

class _BacaBukuScreenState extends State<BacaBukuScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.buku.bookFileUrl != null &&
        widget.buku.bookFileUrl!.isNotEmpty) {
      // Do not initialize WebViewController on web - webview_flutter is not
      // supported on web and will throw. For web we'll open the document in a
      // new browser tab instead.
      if (!kIsWeb) {
        _controller =
            WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..setNavigationDelegate(
                NavigationDelegate(
                  onPageStarted: (String url) {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                    });
                  },
                  onPageFinished: (String url) {
                    setState(() {
                      _isLoading = false;
                    });
                  },
                  onWebResourceError: (WebResourceError error) {
                    setState(() {
                      _isLoading = false;
                      _errorMessage =
                          error.description.isNotEmpty
                              ? error.description
                              : 'Gagal memuat file PDF';
                    });
                  },
                ),
              )
              ..loadRequest(
                Uri.parse(
                  'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.buku.bookFileUrl!)}&embedded=true',
                ),
              );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.buku.bookFileUrl == null || widget.buku.bookFileUrl!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.buku.judul,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF0D47A1),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.book_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'File buku belum tersedia',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Silakan hubungi admin untuk mengunggah file buku',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.buku.judul,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Refresh',
              onPressed: () {
                _controller.reload();
              },
            ),
          IconButton(
            icon: const Icon(Icons.open_in_browser, color: Colors.white),
            tooltip: 'Buka di Browser',
            onPressed: () async {
              final viewer =
                  'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.buku.bookFileUrl!)}&embedded=true';
              await openUrl(viewer);
            },
          ),
        ],
      ),
      body:
          _errorMessage != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gagal memuat buku',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isLoading = true;
                        });
                        _controller.reload();
                      },
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : (kIsWeb
                  ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          const Text('Membuka file buku di tab baru'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final viewer =
                                  'https://docs.google.com/viewer?url=${Uri.encodeComponent(widget.buku.bookFileUrl!)}&embedded=true';
                              await openUrl(viewer);
                            },
                            icon: const Icon(Icons.open_in_browser),
                            label: const Text('Buka di Tab Baru'),
                          ),
                        ],
                      ),
                    ),
                  )
                  : Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_isLoading)
                        Container(
                          color: Colors.white,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('Memuat buku...'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  )),
    );
  }
}
