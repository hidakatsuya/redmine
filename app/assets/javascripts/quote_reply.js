function quoteReply(path, selectorForContentElement, textFormatting) {
  const contentElement = $(selectorForContentElement).get(0);
  const quoteHtml = QuoteExtractor.extract(contentElement);

  let formatter;

  switch (textFormatting) {
    case 'common_mark':
      formatter = new QuoteCommonMarkFormatter(textFormatting);
      break;
    default:
      formatter = new QuoteNullFormatter(textFormatting);
      break;
  }

  $.ajax({
    url: path,
    type: 'post',
    data: { quote: formatter.format(quoteHtml) }
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

    return this.extractHtmlFrom(range)
  }

  extractHtmlFrom(range) {
    const formattedRange = range.toString().trim();
    const dummyContainer = document.createElement('div');

    dummyContainer.appendChild(range.cloneContents());

    return dummyContainer.innerHTML;
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

class QuoteNullFormatter {
  constructor(textFormatting) {
    this.textFormatting = textFormatting;
  }

  format(quoteHtml) {
    return quoteHtml;
  }
}

class QuoteCommonMarkFormatter extends QuoteNullFormatter {
  constructor(textFormatting) {
    super(textFormatting);

    this.turndownService = new TurndownService({
      codeBlockStyle: 'fenced',
      headingStyle: 'atx'
    });
  }

  format(quoteHtml) {
    return this.turndownService.turndown(this.normalize(quoteHtml));
  }

  normalize(quoteHtml) {
    return quoteHtml.replace(/<code class="(.+?) /, '<code class="language-$1 ');
  }
}
