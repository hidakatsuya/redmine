function quoteReply(path, selectorForContentElement) {
  const contentElement = $(selectorForContentElement).get(0);
  const quote = QuoteExtractor.extract(contentElement);

  $.ajax({
    url: path,
    type: 'post',
    data: { quote: quote }
  });
}

class QuoteExtractor {
  static extract(targetElement) {
    return new QuoteExtractor(targetElement).extract();
  }

  constructor(targetElement) {
    this.targetElement = targetElement;
    this.selection = window.getSelection();
  }

  extract() {
    const range = this.selectedRange;

    if (!range) {
      return null;
    }

    if (!this.targetElement.contains(range.startContainer)) {
      range.setStartBefore(this.targetElement);
    }
    if (!this.targetElement.contains(range.endContainer)) {
      range.setEndAfter(this.targetElement);
    }

    return this.formatRange(range);
  }

  formatRange(range) {
    return range.toString().trim();
  }

  get selectedRange() {
    if (!this.isSelected) {
      return null;
    }

    // Retrive the first range that intersects with the target element.
    // NOTE: Firefox allows to select multiple ranges in the document.
    for (let i = 0; i < this.selection.rangeCount; i++) {
      let range = this.selection.getRangeAt(i);
      if (range.intersectsNode(this.targetElement)) {
        return range;
      }
    }
    return null;
  }

  get isSelected() {
    return this.selection.containsNode(this.targetElement, true);
  }
}
