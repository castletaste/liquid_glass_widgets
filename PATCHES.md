# Patches to liquid_glass_widgets

Branch `patches/1.10.0` is upstream tag `v1.10.0` (commit `64ae4e6`) plus the
commits below. Release tags are `v1.10.0-patch.N`. The upstream `lib/` and
`shaders/` at `v1.10.0` are identical to the pub.dev 1.10.0 archive. The
package name, barrel, file set and shader asset keys are upstream's.

| Commit | Change |
|---|---|
| `8a8b5da` | Geometry shader keeps the exterior antialiasing ramp, uses increasing smoothstep edges and guards zero thickness. |
| `2c1f35e` | Blend group pads the geometry matte for the full AA band plus a transparent texel. |
| `fab72aa` | `LiquidGlassSettings.expandNativeEdge` (default `true`): opt out of the iOS 27 silhouette growth; geometry cache invalidation. |
| `238dcd3` | `LiquidGlassSettings.edgeLightWidth` (default `0`): fixed-width edge light, render uniform slot 46. |
| `38963b8` | Touch highlight uses increasing smoothstep edges. |
| `b1f9532` | `LiquidGlassSettings.adaptiveTone` (default `0`): backdrop-driven neutral body, render uniform slots 47–48. |
| `6899129` | `GlassAdaptiveIcon` widget and `shaders/glass_adaptive_icon.frag`. |
| `653496e` | `LiquidGlassWidgets.initialize` no longer preloads `ProgressiveBlur`. |

All new settings default to upstream behaviour. Each commit message explains
the reason for the change.

## Updating to a new upstream release

Rebase the series onto the new upstream tag, drop commits that upstream has
absorbed, and tag `v<upstream>-patch.1`. Then run the dependent app's glass
shader, floating-material, navigation, chrome, press and sheet tests, and check
the glass surfaces visually on Impeller (iOS simulator and a device). Headless
shader tests do not exercise the full backdrop/compositing pipeline.
