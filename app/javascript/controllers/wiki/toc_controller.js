import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="wiki--toc"
export default class extends Controller {
  static targets = ["content"]

  set content(tocElement) {
    this.contentTarget.innerHTML = ""

    if (tocElement) {
      this.contentTarget.appendChild(tocElement)
    }
  }
}
