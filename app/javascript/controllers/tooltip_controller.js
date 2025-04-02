import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
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
