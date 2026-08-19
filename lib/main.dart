import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:evil_space/config.dart';
import 'package:evil_space/pixel_emoji.dart';
import 'package:evil_space/pixeltools.dart';
import 'package:evil_space/localization.dart'; // Adjust path as needed
import 'package:flutter_web_plugins/url_strategy.dart';

// ==========================================================
// 🚀 EDIT YOUR LIVE FEEDS HERE!
// Just add, remove, or edit strings in this list.
// The app will automatically build the menu slots for them.
// ==========================================================
final List<String> liveFeedNews = [
  'MAY PROMO: 10 PERCENT OFF DESKS',
  'NEW PODCAST MICS ARRIVED',
  'JOIN OUR TELEGRAM FOR UPDATES',
];

// ==========================================================
// 📱 EDIT YOUR CONTACT LINKS HERE!
// Add, remove, or edit contacts in this list.
// The contact page will automatically build the menu slots.
// ==========================================================
const List<Map<String, String>> contactLinks = [
  {'label': 'TELEGRAM', 'url': 'https://t.me/your_evil_space'},
  {
    'label': 'INSTAGRAM',
    'url': 'https://www.instagram.com/evil_space_coworking',
  },
  {'label': 'MAP', 'url': 'https://maps.app.goo.gl/5AFFB2AzszcsFvSz5?g_st=ic'},
  {
    'label': 'MESSENGER',
    'url':
        'https://m.me/61585941012998?hash=AbbCb0BDEsCMHEqJ&source_id=8585216',
  },
  {'label': 'ZALO', 'url': 'https://zalo.me/84565056748'},
];

void main() {
  usePathUrlStrategy();
  runApp(const EvilSpacApp());
}

// Added the new pages to the state engine
enum MenuPage { home, feed, desk, office, studio, contact }

class EvilSpacApp extends StatelessWidget {
  const EvilSpacApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Evil Space',
      theme: ThemeData(scaffoldBackgroundColor: const Color(0xFF222222)),
      home: const MatrixScreen(),
    );
  }
}

class MatrixScreen extends StatefulWidget {
  const MatrixScreen({Key? key}) : super(key: key);

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  MenuPage _currentPage = _getInitialPage();
  bool _isInitialLoad = true;
  // pageTransitionMs should match your config.dart, assuming 400ms here as a fallback
  static const int pageTransitionMs = 400;

  static MenuPage _getInitialPage() {
    final String path = Uri.base.path.toLowerCase();
    if (path == '/qr' || path == '/qr/') {
      return MenuPage.contact;
    }
    return MenuPage.home;
  }

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) setState(() => _isInitialLoad = false);
    });
  }

  void _navigateTo(MenuPage page) {
    if (_currentPage == page) return;
    setState(() {
      _currentPage = page;
      _isInitialLoad = false;
    });
  }

  Future<void> _launchApp(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  // ==========================================================
  // 📐 SMART RESPONSIVE LAYOUT ENGINE (AUTO-WRAPPING)
  // ==========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;

          // 1. Fluid sizing logic - Softened to give text more room on narrow screens
          double fluidGrid = screenWidth / 110.0;
          final double gridSize = fluidGrid.clamp(2.5, 8.0);

          // 2. Breakpoint detection
          final bool isMobile = screenWidth < 700;

          // 3. Strict Absolute Anchors
          final double logoX = gridSize * 4;
          final double logoY = gridSize * 5;

          final double mainTitleX = isMobile ? logoX : gridSize * 35;
          final double mainTitleY = isMobile ? gridSize * 25 : gridSize * 8;

          final double pageTitleX = mainTitleX;
          final double pageTitleY = isMobile ? gridSize * 35 : gridSize * 18;

          final double contentStartX = logoX;
          final double contentStartY = isMobile ? gridSize * 48 : gridSize * 30;
          final double contentSpacing = gridSize * 12;

          // 4. SMART WORD-WRAP CALCULATION
          // A pixel character is roughly 5.5 grid units wide. We calculate how many
          // characters can fit before hitting the right edge of the screen.
          final double availableTextWidth =
              screenWidth - (gridSize * 8); // 4 units padding per side
          final int maxCharsPerLine = math.max(
            15,
            (availableTextWidth / (gridSize * 5.5)).floor(),
          );

          // 5. Boundary Protection
          final double requiredContentWidth =
              screenWidth; // Now we wrap instead of scroll!
          final double requiredContentHeight = contentStartY + (gridSize * 100);

          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(screenWidth, requiredContentWidth),
                height: math.max(screenHeight, requiredContentHeight),
                child: Stack(
                  children: [
                    // BACKGROUND GRID
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(gridSize: gridSize),
                      ),
                    ),

                    // HEADER LOGO
                    Positioned(
                      left: logoX,
                      top: logoY,
                      child: HoverablePixelBlock(
                        key: const ValueKey('header_logo'),
                        matrix: Pixelemoji.devilUnframed,
                        gridSize: gridSize,
                        onTap: () => _navigateTo(MenuPage.home),
                      ),
                    ),

                    // HEADER TITLE
                    Positioned(
                      left: mainTitleX,
                      top: mainTitleY,
                      child: HoverablePixelString(
                        key: const ValueKey('header_title'),
                        word: 'EVIL SPACE',
                        gridSize: gridSize,
                        bootDelay: const Duration(milliseconds: 500),
                        isInstant: !_isInitialLoad,
                        onTap: () => _navigateTo(MenuPage.home),
                      ),
                    ),

                    // DYNAMIC PAGES
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Stack(
                          key: ValueKey(_currentPage),
                          children: _getCurrentPageWidgets(
                            gridSize: gridSize,
                            pageTitleX: pageTitleX,
                            pageTitleY: pageTitleY,
                            contentStartX: contentStartX,
                            contentStartY: contentStartY,
                            contentSpacing: contentSpacing,
                            maxCharsPerLine:
                                maxCharsPerLine, // Pass the limits to the pages
                            screenWidth: screenWidth,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================
  // ✂️ THE TEXT WRAPPING HELPER
  // Automatically injects \n so text never cuts off the screen
  // ==========================================================
  String _wrapText(String text, int maxChars) {
    if (text.length <= maxChars) return text;

    final List<String> words = text.split(' ');
    String result = '';
    String currentLine = '';

    for (String word in words) {
      if ((currentLine + word).length > maxChars) {
        if (currentLine.isNotEmpty) {
          result += '${currentLine.trimRight()}\n';
          currentLine = '';
        }
        currentLine = '$word ';
      } else {
        currentLine += '$word ';
      }
    }
    result += currentLine.trimRight();
    return result;
  }

  // ==========================================================
  // 🧩 DYNAMIC PAGE BUILDERS (Y-CURSOR ENGINE)
  // ==========================================================
  List<Widget> _getCurrentPageWidgets({
    required double gridSize,
    required double pageTitleX,
    required double pageTitleY,
    required double contentStartX,
    required double contentStartY,
    required double contentSpacing,
    required int maxCharsPerLine,
    required double screenWidth,
  }) {
    switch (_currentPage) {
      case MenuPage.home:
        return _buildHomePage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
        );
      case MenuPage.feed:
        return _buildFeedPage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
          maxCharsPerLine,
        );
      case MenuPage.desk:
        return _buildDeskPage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
          screenWidth,
        );
      case MenuPage.office:
        return _buildSimplePage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
          'PRIVATE OFFICE',
          'PLEASE CONTACT US\nFOR THE DETAILS',
        );
      case MenuPage.studio:
        return _buildSimplePage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
          'STUDIO RENT',
          'PLEASE CONTACT US\nFOR THE DETAILS',
        );
      case MenuPage.contact:
        return _buildContactPage(
          gridSize,
          pageTitleX,
          pageTitleY,
          contentStartX,
          contentStartY,
        );
    }
  }

  // ----------------------------------------------------------
  // ⚙️ THE GENERALIZED RENDERER
  // This calculates absolute positioning dynamically based on \n count
  // ----------------------------------------------------------
  void _renderFlowList({
    required List<Widget> canvas,
    required double gridSize,
    required double startX,
    required double startY,
    required List<Map<String, dynamic>> items,
    double? secondaryX, // Optional: for right-aligned data like prices
    String? secondaryKey,
  }) {
    double currentY = startY;
    final double lineSpacing = gridSize * 12; // Height of one line of text

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final String label = item['label'];

      // Draw Main Label
      canvas.add(
        Positioned(
          left: startX,
          top: currentY,
          child: HoverablePixelString(
            key: ValueKey('flow_item_${label}_$i'),
            word: label,
            gridSize: gridSize,
            bootDelay: Duration(milliseconds: 650 + (i * 150)),
            isInstant: !_isInitialLoad,
            onTap: item['onTap'],
          ),
        ),
      );

      // Draw Secondary Data (e.g. Price) on the same Y-axis if provided
      if (secondaryX != null &&
          secondaryKey != null &&
          item[secondaryKey] != null) {
        canvas.add(
          Positioned(
            left: secondaryX,
            top: currentY,
            child: HoverablePixelString(
              key: ValueKey('flow_sec_${item[secondaryKey]}_$i'),
              word: item[secondaryKey],
              gridSize: gridSize,
              isInstant: !_isInitialLoad,
            ),
          ),
        );
      }

      // MATHEMATICAL OVERLAP PREVENTION:
      // Count how many lines this label uses, and push the next item down accordingly.
      final int linesCount = label.split('\n').length;
      currentY += lineSpacing * linesCount;
    }
  }

  // ----------------------------------------------------------
  // 🏠 PAGE DEFINITIONS
  // ----------------------------------------------------------
  List<Widget> _buildHomePage(
    double gridSize,
    double titleX,
    double titleY,
    double contentX,
    double contentY,
  ) {
    List<Widget> canvas = [];
    final String title = Localization.get('COWORKING');

    canvas.add(
      Positioned(
        left: titleX,
        top: titleY,
        child: HoverablePixelString(
          key: const ValueKey('home_subtitle'),
          word: title,
          gridSize: gridSize,
          bootDelay: const Duration(milliseconds: 500),
          isInstant: !_isInitialLoad,
        ),
      ),
    );

    // Calculate where content starts dynamically below the title
    final int titleLines = title.split('\n').length;
    final double dynamicContentY =
        titleY + ((gridSize * 12) * titleLines) + (gridSize * 4);

    _renderFlowList(
      canvas: canvas,
      gridSize: gridSize,
      startX: contentX,
      startY: dynamicContentY,
      items: [
        {
          'label': Localization.get('LIVE FEED'),
          'onTap': () => _navigateTo(MenuPage.feed),
        },
        {
          'label': Localization.get('DEDICATED DESK'),
          'onTap': () => _navigateTo(MenuPage.desk),
        },
        {
          'label': Localization.get('PRIVATE OFFICE'),
          'onTap': () => _navigateTo(MenuPage.office),
        },
        {
          'label': Localization.get('PODCAST/VIDEO STUDIO'),
          'onTap': () => _navigateTo(MenuPage.studio),
        },
        {
          'label': Localization.get('CONTACT US'),
          'onTap': () => _navigateTo(MenuPage.contact),
        },
      ],
    );

    return canvas;
  }

  // 💻 UPDATED DESK PAGE (Smart Price Alignment)
  List<Widget> _buildDeskPage(
    double gridSize,
    double titleX,
    double titleY,
    double contentX,
    double contentY,
    double screenWidth,
  ) {
    List<Widget> canvas = [];
    final String title = Localization.get('DEDICATED DESK\nPRICES IN VND');

    // Smart Alignment: Push prices to the right edge, but never let them overlap labels
    final double minimumSafePriceX = contentX + (gridSize * 35);
    final double rightAlignedX = screenWidth - (gridSize * 25);
    final double priceX = math.max(minimumSafePriceX, rightAlignedX);

    canvas.add(
      Positioned(
        left: titleX,
        top: titleY,
        child: HoverablePixelString(
          key: const ValueKey('desk_title'),
          word: title,
          gridSize: gridSize,
          isInstant: true,
        ),
      ),
    );

    final int titleLines = title.split('\n').length;
    final double dynamicContentY =
        titleY + ((gridSize * 12) * titleLines) + (gridSize * 4);

    final deskOptions = [
      {'label': Localization.get('DAY PASS'), 'price': '250K'},
      {'label': Localization.get('WEEK'), 'price': '1.0M'},
      {'label': Localization.get('HOT DESK'), 'price': '3.2M'},
      {'label': Localization.get('PRIVATE DESK'), 'price': '3.5M'},
    ];

    _renderFlowList(
      canvas: canvas,
      gridSize: gridSize,
      startX: contentX,
      startY: dynamicContentY,
      items: deskOptions,
      secondaryX: priceX,
      secondaryKey: 'price',
    );

    return canvas;
  }

  List<Widget> _buildFeedPage(
    double gridSize,
    double titleX,
    double titleY,
    double contentX,
    double contentY,
    int maxChars,
  ) {
    List<Widget> canvas = [];
    final String title = Localization.get('LIVE FEED');

    canvas.add(
      Positioned(
        left: titleX,
        top: titleY,
        child: HoverablePixelString(
          key: const ValueKey('feed_title'),
          word: title,
          gridSize: gridSize,
          isInstant: true,
        ),
      ),
    );

    final int titleLines = title.split('\n').length;
    final double dynamicContentY =
        titleY + ((gridSize * 12) * titleLines) + (gridSize * 4);

    _renderFlowList(
      canvas: canvas,
      gridSize: gridSize,
      startX: contentX,
      startY: dynamicContentY,
      // Wrap the string dynamically before rendering it!
      items: liveFeedNews
          .map(
            (news) => {'label': _wrapText('- $news', maxChars), 'onTap': null},
          )
          .toList(),
    );

    return canvas;
  }

  List<Widget> _buildSimplePage(
    double gridSize,
    double titleX,
    double titleY,
    double contentX,
    double contentY,
    String title,
    String msg,
  ) {
    List<Widget> canvas = [];
    final String localizedTitle = Localization.get(title);

    canvas.add(
      Positioned(
        left: titleX,
        top: titleY,
        child: HoverablePixelString(
          key: ValueKey('${title}_title'),
          word: localizedTitle,
          gridSize: gridSize,
          isInstant: true,
        ),
      ),
    );

    final int titleLines = localizedTitle.split('\n').length;
    final double dynamicContentY =
        titleY + ((gridSize * 12) * titleLines) + (gridSize * 4);

    _renderFlowList(
      canvas: canvas,
      gridSize: gridSize,
      startX: contentX,
      startY: dynamicContentY,
      items: [
        {
          'label': Localization.get(msg),
          'onTap': () => _navigateTo(MenuPage.contact),
        },
      ],
    );

    return canvas;
  }

  List<Widget> _buildContactPage(
    double gridSize,
    double titleX,
    double titleY,
    double contentX,
    double contentY,
  ) {
    List<Widget> canvas = [];
    final String title = Localization.get('CONTACT US');

    canvas.add(
      Positioned(
        left: titleX,
        top: titleY,
        child: HoverablePixelString(
          key: const ValueKey('contact_title'),
          word: title,
          gridSize: gridSize,
          isInstant: true,
        ),
      ),
    );

    final int titleLines = title.split('\n').length;
    final double dynamicContentY =
        titleY + ((gridSize * 12) * titleLines) + (gridSize * 4);

    _renderFlowList(
      canvas: canvas,
      gridSize: gridSize,
      startX: contentX,
      startY: dynamicContentY,
      items: contactLinks
          .map(
            (link) => {
              'label': link['label'],
              'onTap': () => _launchApp(link['url']!),
            },
          )
          .toList(),
    );

    return canvas;
  }
}
