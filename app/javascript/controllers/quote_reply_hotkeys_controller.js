import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static outlets = [ 'quote-reply' ];

  quote(event) {
    if (this.#shouldIgnore(event)) {
      return;
    }

    const selectedQuoteReply = this.#selectedQuoteReplyController;
    if (!selectedQuoteReply) {
      return;
    }

    event.preventDefault();
    selectedQuoteReply.triggerQuote();
  }

  #shouldIgnore(event) {
    return (
      event.defaultPrevented ||
      event.isComposing ||
      event.altKey ||
      event.ctrlKey ||
      event.metaKey ||
      event.shiftKey ||
      event.repeat ||
      this.#isEditableElement(event.target)
    );
  }

  #isEditableElement(element) {
    if (!(element instanceof HTMLElement)) {
      return false;
    }

    return (
      element.tagName === 'INPUT' ||
      element.tagName === 'TEXTAREA' ||
      element.isContentEditable ||
      element.closest('input, textarea, [contenteditable], trix-editor') !== null
    );
  }

  get #selectedQuoteReplyController() {
    if (!this.#hasSelectedRange()) {
      return null;
    }

    return this.quoteReplyOutlets.find(controller => {
      return controller.hasButtonTarget && controller.hasSelectedRange();
    });
  }

  #hasSelectedRange() {
    const selection = window.getSelection();
    if (!selection || selection.rangeCount === 0) {
      return false;
    }

    const range = selection.getRangeAt(0);
    if (range.collapsed) {
      return false;
    }

    return true;
  }
}
