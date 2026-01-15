import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FishSprite extends StatefulWidget {
  /// Path di Storage: contoh "biota/clownfish.png"
  final String storagePath;

  /// Bucket kamu: "aquaverse"
  final String bucket;

  /// Ukuran 1 frame (window)
  final double width;
  final double height;

  /// Durasi loop 4 frame (2x2)
  final Duration duration;

  /// Mirror horizontal (kalau ikan bergerak ke kanan)
  final bool flipX;

  /// Kalau false, tampilkan frame 0 saja (lebih ringan untuk ikan jauh)
  final bool animate;

  const FishSprite({
    super.key,
    required this.storagePath,
    this.bucket = 'aquaverse',
    this.width = 72,
    this.height = 48,
    this.duration = const Duration(milliseconds: 600),
    this.flipX = false,
    this.animate = true,
  });

  @override
  State<FishSprite> createState() => _FishSpriteState();
}

class _FishSpriteState extends State<FishSprite> with TickerProviderStateMixin {
  AnimationController? _controller;
  String? _url;

  @override
  void initState() {
    super.initState();
    _rebuildController();
    _buildUrl();
  }

  @override
  void didUpdateWidget(covariant FishSprite oldWidget) {
    super.didUpdateWidget(oldWidget);

    // rebuild url kalau path/bucket berubah
    if (oldWidget.storagePath != widget.storagePath ||
        oldWidget.bucket != widget.bucket) {
      _buildUrl();
    }

    // rebuild controller kalau animate/duration berubah
    if (oldWidget.animate != widget.animate ||
        oldWidget.duration != widget.duration) {
      _rebuildController();
    }
  }

  void _rebuildController() {
    // selalu dispose controller lama sebelum bikin baru
    _controller?.dispose();
    _controller = null;

    if (widget.animate) {
      _controller = AnimationController(vsync: this, duration: widget.duration)
        ..repeat();
    }
  }

  void _buildUrl() {
    final path = widget.storagePath.trim();
    if (path.isEmpty) {
      if (mounted) setState(() => _url = null);
      return;
    }

    final supabase = Supabase.instance.client;
    final u = supabase.storage.from(widget.bucket).getPublicUrl(path);

    if (mounted) setState(() => _url = u);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  int _currentFrame() {
    if (!widget.animate || _controller == null) return 0;
    return (_controller!.value * 4).floor() % 4;
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.storagePath.trim();

    if (path.isEmpty) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(child: Icon(Icons.image, size: 18)),
      );
    }

    if (_url == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final content = SizedBox(
      width: widget.width,
      height: widget.height,
      child: ClipRect(
        child: (widget.animate && _controller != null)
            ? AnimatedBuilder(
                animation: _controller!,
                builder: (_, __) => _buildFrame(_currentFrame()),
              )
            : _buildFrame(0),
      ),
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()..scale(widget.flipX ? -1.0 : 1.0, 1.0),
      child: content,
    );
  }

  Widget _buildFrame(int frame) {
    final xPos = (frame == 1 || frame == 3) ? -widget.width : 0.0;
    final yPos = (frame == 2 || frame == 3) ? -widget.height : 0.0;

    // cache-busting ringan supaya gak nyangkut gambar ikan lain
    final safeUrl = '$_url?v=${Uri.encodeComponent(widget.storagePath)}';

    return Stack(
      children: [
        Positioned(
          left: xPos,
          top: yPos,
          width: widget.width * 2,
          height: widget.height * 2,
          child: Image.network(
            safeUrl,
            fit: BoxFit.fill,
            gaplessPlayback: true,
            filterQuality: FilterQuality.none,
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image)),
          ),
        ),
      ],
    );
  }
}
