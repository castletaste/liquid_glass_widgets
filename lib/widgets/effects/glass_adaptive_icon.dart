import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../src/engine/liquid_glass.dart';
import '../../src/engine/rendering/liquid_glass_render_object.dart';

/// A monochrome mask composited with a contrasting colour on the GPU.
///
/// [shader] must be an instance of glass_adaptive_icon.frag with sampler 1
/// bound to the mask. The owner retains and disposes both resources. Place
/// inside one own-layer glass surface; translation and axis-aligned scaling
/// are supported. No pixels are read back to the UI isolate.
class GlassAdaptiveIcon extends LeafRenderObjectWidget {
  /// Creates an adaptive glyph of [size] drawn from [shader]'s mask.
  const GlassAdaptiveIcon({
    super.key,
    required this.shader,
    required this.size,
    this.opacity = 1,
    this.pressLight = 0,
  });

  /// An instance of glass_adaptive_icon.frag with sampler 1 bound to the
  /// monochrome mask. Owned and disposed by the caller.
  final ui.FragmentShader shader;

  /// Logical size of the glyph; the mask is stretched to fill it.
  final Size size;

  /// Glyph coverage multiplier, clamped to 0..1.
  final double opacity;

  /// Strength of the press light veil over the backdrop, clamped to 0..0.9.
  /// It is removed before the polarity decision, so pressing cannot flip the
  /// glyph between light and dark ink.
  final double pressLight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAdaptiveIcon(
        shader,
        size,
        MediaQuery.devicePixelRatioOf(context),
        opacity,
        pressLight,
      );

  @override
  void updateRenderObject(
      BuildContext context,
      // ignore: library_private_types_in_public_api
      covariant _RenderAdaptiveIcon renderObject) {
    renderObject.update(shader, size, MediaQuery.devicePixelRatioOf(context),
        opacity, pressLight);
  }
}

class _RenderAdaptiveIcon extends RenderBox {
  _RenderAdaptiveIcon(
      this.shader, this.iconSize, this.dpr, this.opacity, this.pressLight);

  ui.FragmentShader shader;
  Size iconSize;
  double dpr, opacity, pressLight;
  final _clip = LayerHandle<ClipRectLayer>();
  final _filter = LayerHandle<_AdaptiveIconLayer>();

  void update(ui.FragmentShader value, Size dimensions, double ratio,
      double alpha, double light) {
    if (iconSize != dimensions) markNeedsLayout();
    shader = value;
    iconSize = dimensions;
    dpr = ratio;
    opacity = alpha;
    pressLight = light;
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      constraints.constrain(iconSize);

  @override
  void performLayout() => size = computeDryLayout(constraints);

  ui.ImageFilter _createFilter() {
    Rect? pass;
    RenderObject? node = parent;
    var insideShape = false;
    while (node != null) {
      Rect? local;
      if (node is RenderBackdropFilter) {
        local = Offset.zero & node.size;
      } else if (node is RenderLiquidGlass) {
        insideShape = true;
      } else if (node is LiquidGlassRenderObject) {
        if (insideShape || node.encloseDirectChildrenInPass) {
          local = node.backdropPassClipRectLocal;
        }
        insideShape = false;
      }
      if (local != null) {
        pass = MatrixUtils.transformRect(node.getTransformTo(null), local);
        // Pass textures are clipped to the root surface before allocation.
        RenderObject root = node;
        while (root.parent != null) {
          root = root.parent!;
        }
        if (root is RenderView) pass = pass.intersect(Offset.zero & root.size);
        break;
      }
      node = node.parent;
    }
    final bounds =
        MatrixUtils.transformRect(getTransformTo(null), Offset.zero & size);
    final origin = pass == null
        ? Offset.zero
        : Offset(
            (pass.left * dpr).floorToDouble(),
            (pass.top * dpr).floorToDouble(),
          );
    shader
      ..setFloat(2, bounds.left * dpr - origin.dx)
      ..setFloat(3, bounds.top * dpr - origin.dy)
      ..setFloat(4, bounds.width * dpr)
      ..setFloat(5, bounds.height * dpr)
      ..setFloat(6, opacity.clamp(0, 1))
      ..setFloat(7, pressLight.clamp(0, 0.9));
    return ui.ImageFilter.shader(shader);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _filter.layer ??= _AdaptiveIconLayer(_createFilter);
    _clip.layer = context.pushClipRect(true, offset, Offset.zero & size,
        (context, offset) {
      context.pushLayer(_filter.layer!, (context, offset) {}, offset);
    }, oldLayer: _clip.layer);
  }

  @override
  void dispose() {
    _clip.layer = null;
    _filter.layer = null;
    super.dispose();
  }
}

class _AdaptiveIconLayer extends ContainerLayer {
  _AdaptiveIconLayer(this.createFilter);
  final ui.ImageFilter Function() createFilter;

  // A retained TransformLayer can move the icon without repainting it. Derive
  // coordinates at scene composition time so press/release and route motion
  // never leave a mask sampling its previous screen position.
  @override
  bool get alwaysNeedsAddToScene => true;

  @override
  void addToScene(ui.SceneBuilder builder) {
    engineLayer = builder.pushBackdropFilter(
      createFilter(),
      blendMode: BlendMode.src,
      oldLayer: engineLayer as ui.BackdropFilterEngineLayer?,
    );
    addChildrenToScene(builder);
    builder.pop();
  }
}
