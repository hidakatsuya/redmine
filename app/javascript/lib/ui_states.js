const KEY_PREFIX = "redmine"

class UiState {
  #key

  constructor(key) {
    this.#key = [KEY_PREFIX, key].join("-")
  }

  set value(value) {
    if (this.#canUseLocalStorage()) {
      localStorage.setItem(this.#key, value)
    }
  }

  get value() {
    if (this.#canUseLocalStorage()) {
      return localStorage.getItem(this.#key)
    }
  }

  #canUseLocalStorage() {
    try {
      if ("localStorage" in window) {
        localStorage.setItem("redmine.test.storage", "ok")
        const item = localStorage.getItem("redmine.test.storage")
        localStorage.removeItem("redmine.test.storage")

        if (item === "ok") return true
      }
    } catch (err) { }

    return false
  }
}

export const UiStates = {
  ganttColumnWidth(columnName) {
    return new UiState(`gantt-state-column-width-${columnName}`)
  }
}
