/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    text: String
  };

  connect() {
    this.tooltipElement = null;
  }

  disconnect() {
    this.#remove();
  }

  show() {
    if (this.tooltipElement) return;

    const tip = document.createElement('div');
    tip.className = 'tooltip-body';
    tip.textContent = this.textValue;
    document.body.appendChild(tip);
    this.tooltipElement = tip;

    this.#position();
  }

  hide() {
    this.#remove();
  }

  #position() {
    const tip = this.tooltipElement;
    if (!tip) return;

    const rect = this.element.getBoundingClientRect();
    const tipRect = tip.getBoundingClientRect();

    let top = rect.top - tipRect.height - 5;
    let left = rect.left + rect.width / 2 - tipRect.width / 2;

    // If tooltip goes above viewport, show below
    if (top < 0) {
      top = rect.bottom + 5;
    }

    // Keep within horizontal viewport bounds
    if (left < 4) {
      left = 4;
    } else if (left + tipRect.width > window.innerWidth - 4) {
      left = window.innerWidth - tipRect.width - 4;
    }

    tip.style.top = `${top + window.scrollY}px`;
    tip.style.left = `${left + window.scrollX}px`;
  }

  #remove() {
    if (this.tooltipElement) {
      this.tooltipElement.remove();
      this.tooltipElement = null;
    }
  }
}
