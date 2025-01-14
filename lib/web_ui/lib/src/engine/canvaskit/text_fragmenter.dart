// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import '../dom.dart';
import '../text/line_breaker.dart';
import 'canvaskit_api.dart';

/// The granularity at which to segment text.
///
/// To find all supported granularities, see:
/// - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl/Segmenter/Segmenter
enum IntlSegmenterGranularity {
  grapheme,
  word,
}

final Map<IntlSegmenterGranularity, DomSegmenter> _intlSegmenters = <IntlSegmenterGranularity, DomSegmenter>{
  IntlSegmenterGranularity.grapheme: createIntlSegmenter(granularity: 'grapheme'),
  IntlSegmenterGranularity.word: createIntlSegmenter(granularity: 'word'),
};

Uint32List fragmentUsingIntlSegmenter(
  String text,
  IntlSegmenterGranularity granularity,
) {
  final DomSegmenter segmenter = _intlSegmenters[granularity]!;
  final DomIteratorWrapper<DomSegment> iterator = segmenter.segment(text).iterator();

  final List<int> breaks = <int>[];
  while (iterator.moveNext()) {
    breaks.add(iterator.current.index);
  }
  breaks.add(text.length);

  return mallocUint32List(breaks.length).toTypedArray()..setAll(0, breaks);
}

// These are the soft/hard line break values expected by Skia's SkParagraph.
const int _kSoftLineBreak = 0;
const int _kHardLineBreak = 1;

final DomV8BreakIterator _v8LineBreaker = createV8BreakIterator();

Uint32List fragmentUsingV8LineBreaker(String text) {
  final List<LineBreakFragment> fragments =
      breakLinesUsingV8BreakIterator(text, _v8LineBreaker);

  final int size = (fragments.length + 1) * 2;
  final Uint32List typedArray = mallocUint32List(size).toTypedArray();

  typedArray[0] = 0; // start index
  typedArray[1] = _kSoftLineBreak; // break type

  for (int i = 0; i < fragments.length; i++) {
    final LineBreakFragment fragment = fragments[i];
    final int uint32Index = 2 + i * 2;
    typedArray[uint32Index] = fragment.end;
    typedArray[uint32Index + 1] = fragment.type == LineBreakType.mandatory
        ? _kHardLineBreak
        : _kSoftLineBreak;
  }

  return typedArray;
}
