class UiState {
  #key
  constructor(key) {
    this.#key = this.#buildKey(key)
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

  clear() {
    if (this.#canUseLocalStorage()) {
      localStorage.removeItem(this.#key)
    }
  }

  #buildKey(key) {
    return `redmine-${key}`
  }

  #canUseLocalStorage() {
    try {
      if ('localStorage' in window) {
        localStorage.setItem('redmine.test.storage', 'ok')
        const item = localStorage.getItem('redmine.test.storage')
        localStorage.removeItem('redmine.test.storage')

        if (item === 'ok') return true
      }
    } catch (err) { }

    return false
  }
}

export const uiStates = {
  gantt_state_subjects_width: new UiState('gantt-state-column-width-subjects'),
  gantt_state_status_width: new UiState('gantt-state-column-width-status'),
  gantt_state_priority_width: new UiState('gantt-state-column-width-priority'),
  gantt_state_assigned_to_width: new UiState('gantt-state-column-width-assigned_to'),
  gantt_state_updated_on_width: new UiState('gantt-state-column-width-updated_on'),
}
