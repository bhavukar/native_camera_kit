import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controller/native_camera_controller.dart';
import '../models/camera_enums.dart';

/// Renders a hardware-accelerated camera preview backed by native texture streaming.
///
/// Automatically handles sensor aspect ratio, device orientation,
/// front camera mirroring, and tap-to-focus point of interest.
class NativeCameraPreview extends StatefulWidget {
  /// The initialized camera controller.
  final NativeCameraController controller;

  /// Custom widget rendered when the camera preview is not yet initialized.
  final Widget? placeholder;

  /// How the preview texture is scaled and fitted inside its container.
  final BoxFit fit;

  /// Whether tapping on the preview sets the autofocus and autoexposure point of interest.
  final bool enableTapToFocus;

  /// Custom color for the tap-to-focus ring.
  final Color focusRingColor;

  /// Creates a [NativeCameraPreview].
  const NativeCameraPreview({
    super.key,
    required this.controller,
    this.placeholder,
    this.fit = BoxFit.cover,
    this.enableTapToFocus = true,
    this.focusRingColor = Colors.amber,
  });

  @override
  State<NativeCameraPreview> createState() => _NativeCameraPreviewState();
}

class _NativeCameraPreviewState extends State<NativeCameraPreview>
    with SingleTickerProviderStateMixin {
  Offset? _tapPoint;
  late final AnimationController _focusAnimController;
  late final Animation<double> _focusScaleAnim;
  late final Animation<double> _focusOpacityAnim;

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _focusScaleAnim = Tween<double>(begin: 1.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _focusAnimController,
        curve: Curves.easeOutBack,
      ),
    );

    _focusOpacityAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _focusAnimController,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _focusAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _tapPoint = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, BoxConstraints constraints) {
    if (!widget.enableTapToFocus || !widget.controller.value.isInitialized) {
      return;
    }

    final localPos = details.localPosition;
    final normalizedX = (localPos.dx / constraints.maxWidth).clamp(0.0, 1.0);
    final normalizedY = (localPos.dy / constraints.maxHeight).clamp(0.0, 1.0);

    widget.controller.setPointOfInterest(Offset(normalizedX, normalizedY));

    setState(() {
      _tapPoint = localPos;
    });

    _focusAnimController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.controller,
      builder: (context, value, child) {
        if (!value.isInitialized || widget.controller.textureId == null) {
          return widget.placeholder ??
              const Center(
                child: CircularProgressIndicator(),
              );
        }

        final textureId = widget.controller.textureId!;
        final isFront =
            widget.controller.description.position == CameraPosition.front;

        return LayoutBuilder(
          builder: (context, constraints) {
            final previewSize = value.previewSize ?? const Size(1920, 1080);
            final previewAspect = previewSize.height > 0
                ? previewSize.width / previewSize.height
                : 16 / 9;

            Widget textureWidget = Texture(textureId: textureId);

            if (isFront) {
              textureWidget = Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(math.pi),
                child: textureWidget,
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _handleTap(details, constraints),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: previewSize.width,
                      height: previewSize.height,
                      child: AspectRatio(
                        aspectRatio: previewAspect,
                        child: textureWidget,
                      ),
                    ),
                  ),
                  if (_tapPoint != null)
                    AnimatedBuilder(
                      animation: _focusAnimController,
                      builder: (context, child) {
                        const ringSize = 72.0;
                        return Positioned(
                          left: _tapPoint!.dx - (ringSize / 2),
                          top: _tapPoint!.dy - (ringSize / 2),
                          child: Opacity(
                            opacity: _focusOpacityAnim.value,
                            child: Transform.scale(
                              scale: _focusScaleAnim.value,
                              child: Container(
                                width: ringSize,
                                height: ringSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.rectangle,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: widget.focusRingColor,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
