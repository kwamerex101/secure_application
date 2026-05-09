import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secure_application/secure_application_controller.dart';
import 'package:secure_application/secure_application_native.dart';
import 'package:secure_application/secure_application_provider.dart';

/// Displays a frost overlay above [child] whenever the surrounding
/// [SecureApplicationController] reports `locked == true`.
///
/// Tweak [opacity] and [blurr] to control how much of the underlying
/// content shows through. Set [fullScreen] to `true` to render the gate
/// into the root [Overlay] so it covers status / navigation bars even
/// when this widget is mounted inside a `Scaffold`.
class SecureGate extends StatefulWidget {
  /// Child to display when unlocked.
  final Widget child;

  /// Builder for the locked-state UI rendered above the blur (e.g. a
  /// biometric prompt). Receives the active controller so the builder
  /// can call `controller.unlock()` once auth succeeds.
  final Widget Function(BuildContext context,
      SecureApplicationController? secureApplicationController)? lockedBuilder;

  /// Sigma value passed to [ImageFilter.blur]. Default: 20.
  final double blurr;

  /// Tint applied above the blur. Default: 0.6.
  final double opacity;

  /// When `true`, renders the gate into the root [Overlay] so it covers
  /// the entire screen (status bar, app bar, navigation bar) regardless
  /// of where this widget sits in the tree. Default: `false` (keeps
  /// legacy in-tree behaviour).
  final bool fullScreen;

  /// When `true`, switches the system UI to [SystemUiMode.immersiveSticky]
  /// while locked and restores [SystemUiMode.edgeToEdge] on unlock. Useful
  /// to hide system chrome behind the gate. Default: `false`.
  final bool immersiveWhenLocked;

  const SecureGate({
    Key? key,
    required this.child,
    this.blurr = 20,
    this.opacity = 0.6,
    this.lockedBuilder,
    this.fullScreen = false,
    this.immersiveWhenLocked = false,
  }) : super(key: key);

  @override
  _SecureGateState createState() => _SecureGateState();
}

class _SecureGateState extends State<SecureGate>
    with SingleTickerProviderStateMixin {
  bool _lock = false;
  late AnimationController _gateVisibility;
  SecureApplicationController? _secureApplicationController;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    _gateVisibility =
        AnimationController(vsync: this, duration: kThemeAnimationDuration * 2)
          ..addListener(_handleChange);
    SecureApplicationNative.opacity(widget.opacity);
    super.initState();
  }

  @override
  void didChangeDependencies() {
    if (_secureApplicationController == null) {
      _secureApplicationController = SecureApplicationProvider.of(context);
      _secureApplicationController!.addListener(_sercureNotified);
      _sercureNotified();
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(SecureGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opacity != widget.opacity) {
      SecureApplicationNative.opacity(widget.opacity);
    }
    if (oldWidget.fullScreen != widget.fullScreen) {
      // Toggling mode while mounted: rebuild the overlay if needed.
      _removeOverlay();
      if (_lock && widget.fullScreen) _insertOverlay();
    }
  }

  void _sercureNotified() {
    if (_lock == false && _secureApplicationController!.locked == true) {
      _lock = true;
      _gateVisibility.value = 1;
      if (widget.fullScreen) _insertOverlay();
      if (widget.immersiveWhenLocked) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
    } else if (_lock == true && _secureApplicationController!.locked == false) {
      _lock = false;
      _gateVisibility.animateBack(0).whenCompleteOrCancel(() {
        if (!mounted) return;
        _removeOverlay();
      });
      if (widget.immersiveWhenLocked) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
  }

  void _handleChange() {
    if (mounted) setState(() {});
    _overlayEntry?.markNeedsBuild();
  }

  void _insertOverlay() {
    if (_overlayEntry != null) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _overlayEntry = OverlayEntry(builder: _buildGateLayer);
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _secureApplicationController?.removeListener(_sercureNotified);
    _gateVisibility.dispose();
    super.dispose();
  }

  Widget _buildGateLayer(BuildContext context) {
    final visibility = _gateVisibility.value;
    if (visibility == 0 && !_lock) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: !_lock,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: widget.blurr * visibility,
                sigmaY: widget.blurr * visibility),
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.grey.shade200
                      .withValues(alpha: widget.opacity * visibility)),
            ),
          ),
          if (_lock && widget.lockedBuilder != null)
            widget.lockedBuilder!(context, _secureApplicationController),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullScreen) {
      // Gate is rendered via the root Overlay; only render the child here.
      return widget.child;
    }
    return Stack(
      children: <Widget>[
        widget.child,
        if (_gateVisibility.value != 0)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: widget.blurr * _gateVisibility.value,
                  sigmaY: widget.blurr * _gateVisibility.value),
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.grey.shade200.withValues(
                        alpha: widget.opacity * _gateVisibility.value)),
              ),
            ),
          ),
        if (_lock && widget.lockedBuilder != null)
          widget.lockedBuilder!(context, _secureApplicationController),
      ],
    );
  }
}
