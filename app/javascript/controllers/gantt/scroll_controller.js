import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["header", "body", "timelineHeader", "timeline"]

  #syncedPositions = null

  connect() {
    this.#syncedPositions = new WeakMap()
    this.syncColumns({ currentTarget: this.bodyTarget })
    this.syncTimeline({ currentTarget: this.timelineTarget })
  }

  syncColumns(event) {
    this.#sync(event.currentTarget, this.headerTarget, this.bodyTarget)
  }

  syncTimeline(event) {
    // Labels may extend beyond the last day. Give both panes the same scroll range.
    const width = `${this.timelineTarget.scrollWidth}px`
    if (this.timelineHeaderTarget.style.getPropertyValue("--gantt-timeline-scroll-width") !== width) {
      this.timelineHeaderTarget.style.setProperty("--gantt-timeline-scroll-width", width)
    }
    this.#sync(event.currentTarget, this.timelineHeaderTarget, this.timelineTarget)
  }

  #sync(source, header, body) {
    const position = source.scrollLeft
    const syncedPosition = this.#syncedPositions.get(source)
    this.#syncedPositions.delete(source)
    // A scroll caused by synchronization must not write an old position back
    // to the element the user is still scrolling.
    if (position === syncedPosition) return

    const destination = source === body ? header : body
    if (destination.scrollLeft !== position) {
      destination.scrollLeft = position
      this.#syncedPositions.set(destination, destination.scrollLeft)
    }
  }
}
