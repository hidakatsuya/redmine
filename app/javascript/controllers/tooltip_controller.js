/**
 * Redmine - project management software
 * Copyright (C) 2006-  Jean-Philippe Lang
 * This code is released under the GNU General Public License.
 */
import { Controller } from "@hotwired/stimulus"

let tooltipId = 0;

export default class extends Controller {
  static targets = ['trigger'];

  initialize() {
    this.show = this.show.bind(this);
    this.hide = this.hide.bind(this);
    this.handleKeyup = this.handleKeyup.bind(this);
  }

  connect() {
    this.tooltipElement = null;
    this.activeTrigger = null;
    this.activeTitle = null;
    this.showTimeout = null;
  }

  disconnect() {
    this.triggerTargets.forEach((element) => this.#stopListening(element));
    this.hide();
  }

  // Event listeners are managed here so that one application-wide controller
  // can enhance title attributes while preserving them for non-JS renderers.
  // This is specific to tooltips and is not a general controller pattern.
  triggerTargetConnected(element) {
    this.#startListening(element);
  }

  triggerTargetDisconnected(element) {
    this.#stopListening(element);

    if (element === this.activeTrigger) {
      this.hide();
    }
  }

  #startListening(element) {
    element.addEventListener('mouseenter', this.show);
    element.addEventListener('mouseleave', this.hide);
    element.addEventListener('focusin', this.show);
    element.addEventListener('focusout', this.hide);
    element.addEventListener('keyup', this.handleKeyup);
  }

  #stopListening(element) {
    element.removeEventListener('mouseenter', this.show);
    element.removeEventListener('mouseleave', this.hide);
    element.removeEventListener('focusin', this.show);
    element.removeEventListener('focusout', this.hide);
    element.removeEventListener('keyup', this.handleKeyup);
  }

  show(event) {
    const trigger = event.currentTarget;
    if (trigger === this.activeTrigger) return;

    this.hide();

    const title = trigger.getAttribute('title');
    if (!title) return;

    this.activeTrigger = trigger;
    this.activeTitle = title;
    trigger.removeAttribute('title');

    this.showTimeout = window.setTimeout(() => {
      this.showTimeout = null;
      this.#create();
    }, 400);
  }

  hide() {
    if (this.showTimeout) {
      window.clearTimeout(this.showTimeout);
      this.showTimeout = null;
    }

    if (this.activeTrigger) {
      if (this.activeTitle !== null && !this.activeTrigger.hasAttribute('title')) {
        this.activeTrigger.setAttribute('title', this.activeTitle);
      }
      this.#removeDescribedBy(this.activeTrigger);
    }

    this.#remove();

    this.activeTrigger = null;
    this.activeTitle = null;
  }

  handleKeyup(event) {
    if (event.key === 'Escape' && event.currentTarget === this.activeTrigger) {
      this.hide();
    }
  }

  #create() {
    if (!this.activeTrigger || this.tooltipElement) return;

    const tip = document.createElement('div');
    tip.id = `tooltip-${++tooltipId}`;
    tip.className = 'tooltip-body';
    tip.setAttribute('role', 'tooltip');
    tip.textContent = this.activeTitle;
    document.body.appendChild(tip);
    this.tooltipElement = tip;
    this.#addDescribedBy(this.activeTrigger, tip.id);

    this.#position();
  }

  #position() {
    const tip = this.tooltipElement;
    if (!tip || !this.activeTrigger) return;

    const rect = this.activeTrigger.getBoundingClientRect();
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

  #addDescribedBy(trigger, id) {
    const ids = (trigger.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
    ids.push(id);
    trigger.setAttribute('aria-describedby', ids.join(' '));
  }

  #removeDescribedBy(trigger) {
    if (!this.tooltipElement) return;

    const ids = (trigger.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean);
    const remainingIds = ids.filter((id) => id !== this.tooltipElement.id);
    if (remainingIds.length) {
      trigger.setAttribute('aria-describedby', remainingIds.join(' '));
    } else {
      trigger.removeAttribute('aria-describedby');
    }
  }

  #remove() {
    if (this.tooltipElement) {
      this.tooltipElement.remove();
      this.tooltipElement = null;
    }
  }
}
