import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { content: String }

  connect() {
    this.element.setAttribute("title", this.contentValue);

    $(this.element).tooltip({
      show: {
        delay: 400
      },
      position: {
        my: "center bottom-5",
        at: "center top"
      }
    });
  }

  disconnect() {
    $(this.element).tooltip("destroy");
  }
}
