import 'dart:async';
import 'package:flutter/material.dart';

import '../services/homepage_service.dart';
import '../settings/app_settings.dart';

/// Published homepage banners, preserving the server's order and actions.
class HomeHeroBanner extends StatefulWidget {
  const HomeHeroBanner({super.key, required this.items, required this.onOpen,
    this.interval = const Duration(seconds: 5)});
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final Duration interval;

  @override
  State<HomeHeroBanner> createState() => _HomeHeroBannerState();
}

class _HomeHeroBannerState extends State<HomeHeroBanner> with WidgetsBindingObserver {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;
  bool _paused = false, _dragging = false, _active = true, _enabled = true;
  bool _routeCurrent = true;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _enabled = TickerMode.of(context);
    _routeCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant HomeHeroBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.items.map((v) => v['id']).join(',');
    final newIds = widget.items.map((v) => v['id']).join(',');
    if (oldIds != newIds) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) _controller.jumpToPage(0);
      });
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!_active || !_enabled || !_routeCurrent || _reduceMotion ||
        _paused || _dragging || widget.items.length < 2) return;
    _timer = Timer(widget.interval, () {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.items.length;
      if (next == 0) {
        _controller.jumpToPage(0);
      } else {
        _controller.animateToPage(next, duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut);
      }
      _schedule();
    });
  }

  void _go(int i) {
    if (!_controller.hasClients) return;
    if (_reduceMotion) {
      _controller.jumpToPage(i);
    } else {
      _controller.animateToPage(i, duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut);
    }
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  String _local(Map<String, dynamic> row, String field) {
    final bn = HomepageService.text(row, field);
    final en = HomepageService.text(row, '${field}_en');
    return AppText.of(context, bn, en.isEmpty ? bn : en);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final height = (constraints.maxWidth * .48).clamp(170.0, 300.0).toDouble()
            + (scale > 1 ? (scale - 1) * 100 : 0);
        return Column(children: [
          SizedBox(height: height, child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.depth == 0 && n is ScrollStartNotification && n.dragDetails != null) {
                _dragging = true;
                _schedule();
              } else if (n.depth == 0 && n is ScrollEndNotification) {
                _dragging = false;
                _schedule();
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              onPageChanged: (i) { setState(() => _index = i); _schedule(); },
              itemBuilder: (context, i) {
                final row = widget.items[i];
                final image = HomepageService.text(row, 'image_url');
                final hasImage = HomepageService.safeImage(image);
                final title = _local(row, 'title');
                final body = _local(row, 'body');
                return Material(
                  borderRadius: BorderRadius.circular(20),
                  clipBehavior: Clip.antiAlias,
                  color: const Color(0xFF650D18),
                  child: InkWell(
                    onTap: () => widget.onOpen(row),
                    child: Stack(fit: StackFit.expand, children: [
                      const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                        colors: [Color(0xFF36060D), Color(0xFF8D1723)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ))),
                      if (hasImage) Image.network(image, fit: BoxFit.cover,
                        excludeFromSemantics: true, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      if (hasImage) const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0x22000000), Color(0xE5000000)],
                      ))),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end, children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text(body, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Flexible(child: Text(AppText.of(context, 'বিস্তারিত দেখুন', 'View details'),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Color(0xFFFFD394), fontWeight: FontWeight.w700))),
                            const Icon(Icons.chevron_right, color: Color(0xFFFFD394), size: 18),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                );
              },
            ),
          )),
          if (widget.items.length > 1) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < widget.items.length; i++)
              Semantics(button: true, selected: i == _index,
                label: AppText.of(context, 'ব্যানার ${i+1}', 'Banner ${i+1}'),
                child: InkWell(onTap: () => _go(i), borderRadius: BorderRadius.circular(20),
                  child: SizedBox(width: 26, height: 44, child: Center(child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == _index ? 16 : 7, height: 7,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                      color: i == _index ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline),
                  ))))),
            if (!_reduceMotion) IconButton(
              tooltip: _paused ? 'Resume auto slide' : 'Pause auto slide',
              onPressed: () { setState(() => _paused = !_paused); _schedule(); },
              icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 19),
            ),
          ]),
        ]);
      }),
    );
  }
}
