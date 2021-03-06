// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'basic_types.dart';

/// A normal font weight
const normal = FontWeight.w400;

/// A bold font weight
const bold = FontWeight.w700;

/// Draw a line underneath each line of text
const underline = const <TextDecoration>[TextDecoration.underline];

/// Draw a line above each line of text
const overline = const <TextDecoration>[TextDecoration.overline];

/// Draw a line through each line of text
const lineThrough = const <TextDecoration>[TextDecoration.lineThrough];

/// An immutable style in which paint text
class TextStyle {
  const TextStyle({
    this.inherit: true,
    this.color,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.textAlign,
    this.textBaseline,
    this.height,
    this.decoration,
    this.decorationColor,
    this.decorationStyle
  });

  /// Whether null values are replaced with their value in an ancestor text style.
  final bool inherit;

  /// The color to use when painting the text
  final Color color;

  /// The name of the font to use when painting the text
  final String fontFamily;

  /// The size of gyphs (in logical pixels) to use when painting the text
  final double fontSize;

  /// The font weight to use when painting the text
  final FontWeight fontWeight;

  /// The font style to use when painting the text
  final FontStyle fontStyle;

  /// How the text should be aligned (applies only to the outermost
  /// StyledTextSpan, which establishes the container for the text)
  final TextAlign textAlign;

  /// The baseline to use for aligning the text
  final TextBaseline textBaseline;

  /// The distance between the text baselines, as a multiple of the font size
  final double height;

  /// A list of decorations to paint near the text
  final List<TextDecoration> decoration; // TODO(ianh): Switch this to a Set<> once Dart supports constant Sets

  /// The color in which to paint the text decorations
  final Color decorationColor;

  /// The style in which to paint the text decorations
  final TextDecorationStyle decorationStyle;

  /// Returns a new text style that matches this text style but with the given
  /// values replaced
  TextStyle copyWith({
    Color color,
    String fontFamily,
    double fontSize,
    FontWeight fontWeight,
    FontStyle fontStyle,
    TextAlign textAlign,
    TextBaseline textBaseline,
    double height,
    List<TextDecoration> decoration,
    Color decorationColor,
    TextDecorationStyle decorationStyle
  }) {
    return new TextStyle(
      inherit: inherit,
      color: color != null ? color : this.color,
      fontFamily: fontFamily != null ? fontFamily : this.fontFamily,
      fontSize: fontSize != null ? fontSize : this.fontSize,
      fontWeight: fontWeight != null ? fontWeight : this.fontWeight,
      fontStyle: fontStyle != null ? fontStyle : this.fontStyle,
      textAlign: textAlign != null ? textAlign : this.textAlign,
      textBaseline: textBaseline != null ? textBaseline : this.textBaseline,
      height: height != null ? height : this.height,
      decoration: decoration != null ? decoration : this.decoration,
      decorationColor: decorationColor != null ? decorationColor : this.decorationColor,
      decorationStyle: decorationStyle != null ? decorationStyle : this.decorationStyle
    );
  }

  /// Returns a new text style that matches this text style but with some values
  /// replaced by the non-null parameters of the given text style. If the given
  /// text style is null, simply returns this text style.
  TextStyle merge(TextStyle other) {
    if (other == null)
      return this;
    assert(other.inherit);
    return copyWith(
      color: other.color,
      fontFamily: other.fontFamily,
      fontSize: other.fontSize,
      fontWeight: other.fontWeight,
      fontStyle: other.fontStyle,
      textAlign: other.textAlign,
      textBaseline: other.textBaseline,
      height: other.height,
      decoration: other.decoration,
      decorationColor: other.decorationColor,
      decorationStyle: other.decorationStyle
    );
  }

  ui.TextStyle get textStyle {
    return new ui.TextStyle(
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      fontFamily: fontFamily,
      fontSize: fontSize
    );
  }

  ui.ParagraphStyle get paragraphStyle {
    return new ui.ParagraphStyle(
      textAlign: textAlign,
      textBaseline: textBaseline,
      lineHeight: height
    );
  }

  bool operator ==(dynamic other) {
    if (identical(this, other))
      return true;
    if (other is! TextStyle)
      return false;
    final TextStyle typedOther = other;
    return inherit == typedOther.inherit &&
           color == typedOther.color &&
           fontFamily == typedOther.fontFamily &&
           fontSize == typedOther.fontSize &&
           fontWeight == typedOther.fontWeight &&
           fontStyle == typedOther.fontStyle &&
           textAlign == typedOther.textAlign &&
           textBaseline == typedOther.textBaseline &&
           decoration == typedOther.decoration &&
           decorationColor == typedOther.decorationColor &&
           decorationStyle == typedOther.decorationStyle;
  }

  int get hashCode {
    // Use Quiver: https://github.com/domokit/mojo/issues/236
    int value = 373;
    value = 37 * value + inherit.hashCode;
    value = 37 * value + color.hashCode;
    value = 37 * value + fontFamily.hashCode;
    value = 37 * value + fontSize.hashCode;
    value = 37 * value + fontWeight.hashCode;
    value = 37 * value + fontStyle.hashCode;
    value = 37 * value + textAlign.hashCode;
    value = 37 * value + textBaseline.hashCode;
    value = 37 * value + decoration.hashCode;
    value = 37 * value + decorationColor.hashCode;
    value = 37 * value + decorationStyle.hashCode;
    return value;
  }

  String toString([String prefix = '']) {
    List<String> result = <String>[];
    result.add('${prefix}inhert: $inherit');
    if (color != null)
      result.add('${prefix}color: $color');
    if (fontFamily != null)
      result.add('${prefix}family: "$fontFamily"');
    if (fontSize != null)
      result.add('${prefix}size: $fontSize');
    if (fontWeight != null) {
      switch (fontWeight) {
        case FontWeight.w100:
          result.add('${prefix}weight: 100');
          break;
        case FontWeight.w200:
          result.add('${prefix}weight: 200');
          break;
        case FontWeight.w300:
          result.add('${prefix}weight: 300');
          break;
        case FontWeight.w400:
          result.add('${prefix}weight: 400');
          break;
        case FontWeight.w500:
          result.add('${prefix}weight: 500');
          break;
        case FontWeight.w600:
          result.add('${prefix}weight: 600');
          break;
        case FontWeight.w700:
          result.add('${prefix}weight: 700');
          break;
        case FontWeight.w800:
          result.add('${prefix}weight: 800');
          break;
        case FontWeight.w900:
          result.add('${prefix}weight: 900');
          break;
      }
    }
    if (fontStyle != null) {
      switch (fontStyle) {
        case FontStyle.normal:
          result.add('${prefix}style: normal');
          break;
        case FontStyle.italic:
          result.add('${prefix}style: italic');
          break;
      }
    }
    if (textAlign != null) {
      switch (textAlign) {
        case TextAlign.left:
          result.add('${prefix}align: left');
          break;
        case TextAlign.right:
          result.add('${prefix}align: right');
          break;
        case TextAlign.center:
          result.add('${prefix}align: center');
          break;
      }
    }
    if (textBaseline != null) {
      switch (textBaseline) {
        case TextBaseline.alphabetic:
          result.add('${prefix}baseline: alphabetic');
          break;
        case TextBaseline.ideographic:
          result.add('${prefix}baseline: ideographic');
          break;
      }
    }
    if (decoration != null || decorationColor != null || decorationStyle != null) {
      String decorationDescription = '${prefix}decoration: ';
      bool haveDecorationDescription = false;
      if (decorationStyle != null) {
        switch (decorationStyle) {
          case TextDecorationStyle.solid:
            decorationDescription += 'solid';
            break;
          case TextDecorationStyle.double:
            decorationDescription += 'double';
            break;
          case TextDecorationStyle.dotted:
            decorationDescription += 'dotted';
            break;
          case TextDecorationStyle.dashed:
            decorationDescription += 'dashed';
            break;
          case TextDecorationStyle.wavy:
            decorationDescription += 'wavy';
            break;
        }
        haveDecorationDescription = true;
      }
      if (decorationColor != null) {
        if (haveDecorationDescription)
          decorationDescription += ' ';
        decorationDescription += '$decorationColor';
        haveDecorationDescription = true;
      }
      if (decoration != null) {
        if (haveDecorationDescription)
          decorationDescription += ' ';
        bool multipleDecorations = false;
        for (TextDecoration value in decoration) {
          if (multipleDecorations)
            decorationDescription += '+';
          switch (value) {
            case TextDecoration.none:
              decorationDescription += 'none';
              break;
            case TextDecoration.underline:
              decorationDescription += 'underline';
              break;
            case TextDecoration.overline:
              decorationDescription += 'overline';
              break;
            case TextDecoration.lineThrough:
              decorationDescription += 'line-through';
              break;
          }
          multipleDecorations = true;
        }
        haveDecorationDescription = true;
      }
      assert(haveDecorationDescription);
      result.add(decorationDescription);
    }
    if (result.isEmpty)
      return '$prefix<no style specified>';
    return result.join('\n');
  }
}
