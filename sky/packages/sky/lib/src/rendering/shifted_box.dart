// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/painting.dart';

import 'box.dart';
import 'object.dart';

abstract class RenderShiftedBox extends RenderBox with RenderObjectWithChildMixin<RenderBox> {

  // Abstract class for one-child-layout render boxes

  RenderShiftedBox(RenderBox child) {
    this.child = child;
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicWidth(constraints);
    return super.getMinIntrinsicWidth(constraints);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints);
    return super.getMaxIntrinsicWidth(constraints);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMinIntrinsicHeight(constraints);
    return super.getMinIntrinsicHeight(constraints);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    if (child != null)
      return child.getMaxIntrinsicHeight(constraints);
    return super.getMaxIntrinsicHeight(constraints);
  }

  double computeDistanceToActualBaseline(TextBaseline baseline) {
    double result;
    if (child != null) {
      assert(!needsLayout);
      result = child.getDistanceToActualBaseline(baseline);
      final BoxParentData childParentData = child.parentData;
      if (result != null)
        result += childParentData.position.y;
    } else {
      result = super.computeDistanceToActualBaseline(baseline);
    }
    return result;
  }

  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final BoxParentData childParentData = child.parentData;
      context.paintChild(child, childParentData.position + offset);
    }
  }

  void hitTestChildren(HitTestResult result, { Point position }) {
    if (child != null) {
      final BoxParentData childParentData = child.parentData;
      child.hitTest(result, position: new Point(position.x - childParentData.position.x,
                                                position.y - childParentData.position.y));
    }
  }

}

class RenderPadding extends RenderShiftedBox {

  RenderPadding({ EdgeDims padding, RenderBox child }) : super(child) {
    assert(padding != null);
    this.padding = padding;
  }

  EdgeDims _padding;
  EdgeDims get padding => _padding;
  void set padding (EdgeDims value) {
    assert(value != null);
    assert(value.isNonNegative);
    if (_padding == value)
      return;
    _padding = value;
    markNeedsLayout();
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    double totalPadding = padding.left + padding.right;
    if (child != null)
      return child.getMinIntrinsicWidth(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainWidth(totalPadding);
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    double totalPadding = padding.left + padding.right;
    if (child != null)
      return child.getMaxIntrinsicWidth(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainWidth(totalPadding);
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    double totalPadding = padding.top + padding.bottom;
    if (child != null)
      return child.getMinIntrinsicHeight(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainHeight(totalPadding);
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    double totalPadding = padding.top + padding.bottom;
    if (child != null)
      return child.getMaxIntrinsicHeight(constraints.deflate(padding)) + totalPadding;
    return constraints.constrainHeight(totalPadding);
  }

  void performLayout() {
    assert(padding != null);
    if (child == null) {
      size = constraints.constrain(new Size(
        padding.left + padding.right,
        padding.top + padding.bottom
      ));
      return;
    }
    BoxConstraints innerConstraints = constraints.deflate(padding);
    child.layout(innerConstraints, parentUsesSize: true);
    final BoxParentData childParentData = child.parentData;
    childParentData.position = new Point(padding.left, padding.top);
    size = constraints.constrain(new Size(
      padding.left + child.size.width + padding.right,
      padding.top + child.size.height + padding.bottom
    ));
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}padding: $padding\n';
}

enum ShrinkWrap {
  width,
  height,
  both,
  none
}

class RenderPositionedBox extends RenderShiftedBox {

  // This box aligns a child box within itself. It's only useful for
  // children that don't always size to fit their parent. For example,
  // to align a box at the bottom right, you would pass this box a
  // tight constraint that is bigger than the child's natural size,
  // with horizontal and vertical set to 1.0.

  RenderPositionedBox({
    RenderBox child,
    FractionalOffset alignment: const FractionalOffset(0.5, 0.5),
    ShrinkWrap shrinkWrap: ShrinkWrap.none
  }) : _alignment = alignment,
       _shrinkWrap = shrinkWrap,
       super(child) {
    assert(alignment != null);
    assert(shrinkWrap != null);
  }

  FractionalOffset get alignment => _alignment;
  FractionalOffset _alignment;
  void set alignment (FractionalOffset newAlignment) {
    assert(newAlignment == null || (newAlignment.x != null && newAlignment.y != null));
    if (_alignment == newAlignment)
      return;
    _alignment = newAlignment;
    markNeedsLayout();
  }

  ShrinkWrap _shrinkWrap;
  ShrinkWrap get shrinkWrap => _shrinkWrap;
  void set shrinkWrap (ShrinkWrap value) {
    assert(value != null);
    if (_shrinkWrap == value)
      return;
    _shrinkWrap = value;
    markNeedsLayout();
  }

  // These are only valid during performLayout() and paint(), since they rely on constraints which is only set after layout() is called.
  bool get _shinkWrapWidth => _shrinkWrap == ShrinkWrap.width || _shrinkWrap == ShrinkWrap.both || constraints.maxWidth == double.INFINITY;
  bool get _shinkWrapHeight => _shrinkWrap == ShrinkWrap.height || _shrinkWrap == ShrinkWrap.both || constraints.maxHeight == double.INFINITY;

  void performLayout() {
    if (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(new Size(_shinkWrapWidth ? child.size.width : double.INFINITY,
                                            _shinkWrapHeight ? child.size.height : double.INFINITY));
      Offset delta = size - child.size;
      final BoxParentData childParentData = child.parentData;
      childParentData.position = (delta.scale(_alignment.x, _alignment.y)).toPoint();
    } else {
      size = constraints.constrain(new Size(_shinkWrapWidth ? 0.0 : double.INFINITY,
                                            _shinkWrapHeight ? 0.0 : double.INFINITY));
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}alignment: $alignment\n';
}

/// A delegate for computing the layout of a render object with a single child.
class OneChildLayoutDelegate {
  /// Returns the size of this object given the incomming constraints.
  Size getSize(BoxConstraints constraints) => constraints.biggest;

  /// Returns the box constraints for the child given the incomming constraints.
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => constraints;

  /// Returns the position where the child should be placed given the size of this object and the size of the child.
  Point getPositionForChild(Size size, Size childSize) => Point.origin;
}

class RenderCustomOneChildLayoutBox extends RenderShiftedBox {
  RenderCustomOneChildLayoutBox({
    RenderBox child,
    OneChildLayoutDelegate delegate
  }) : _delegate = delegate, super(child) {
    assert(delegate != null);
  }

  OneChildLayoutDelegate get delegate => _delegate;
  OneChildLayoutDelegate _delegate;
  void set delegate (OneChildLayoutDelegate newDelegate) {
    assert(newDelegate != null);
    if (_delegate == newDelegate)
      return;
    _delegate = newDelegate;
    markNeedsLayout();
  }

  Size _getSize(BoxConstraints constraints) {
    return constraints.constrain(_delegate.getSize(constraints));
  }

  double getMinIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  double getMaxIntrinsicWidth(BoxConstraints constraints) {
    return _getSize(constraints).width;
  }

  double getMinIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  double getMaxIntrinsicHeight(BoxConstraints constraints) {
    return _getSize(constraints).height;
  }

  bool get sizedByParent => true;

  void performResize() {
    size = _getSize(constraints);
  }

  void performLayout() {
    if (child != null) {
      child.layout(delegate.getConstraintsForChild(constraints), parentUsesSize: true);
      final BoxParentData childParentData = child.parentData;
      childParentData.position = delegate.getPositionForChild(size, child.size);
    }
  }
}

class RenderBaseline extends RenderShiftedBox {

  RenderBaseline({
    RenderBox child,
    double baseline,
    TextBaseline baselineType
  }) : _baseline = baseline,
       _baselineType = baselineType,
       super(child) {
    assert(baseline != null);
    assert(baselineType != null);
  }

  double _baseline;
  double get baseline => _baseline;
  void set baseline (double value) {
    assert(value != null);
    if (_baseline == value)
      return;
    _baseline = value;
    markNeedsLayout();
  }

  TextBaseline _baselineType;
  TextBaseline get baselineType => _baselineType;
  void set baselineType (TextBaseline value) {
    assert(value != null);
    if (_baselineType == value)
      return;
    _baselineType = value;
    markNeedsLayout();
  }

  void performLayout() {
    if (child != null) {
      child.layout(constraints.loosen(), parentUsesSize: true);
      size = constraints.constrain(child.size);
      double delta = baseline - child.getDistanceToBaseline(baselineType);
      final BoxParentData childParentData = child.parentData;
      childParentData.position = new Point(0.0, delta);
    } else {
      performResize();
    }
  }

  String debugDescribeSettings(String prefix) => '${super.debugDescribeSettings(prefix)}${prefix}baseline: $baseline\nbaselineType: $baselineType';
}
