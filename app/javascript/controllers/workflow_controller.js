import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["form", "submit"]

  connect() {
    this.originalState = this.captureCurrentState()
    this.setupChangeListeners()
  }

  captureCurrentState() {
    const state = {}
    const checkboxes = this.formTarget.querySelectorAll('input[type="checkbox"][name^="transitions"]')
    
    checkboxes.forEach(checkbox => {
      if (!checkbox.disabled) {
        state[checkbox.name] = checkbox.checked
      }
    })
    
    return state
  }

  setupChangeListeners() {
    const checkboxes = this.formTarget.querySelectorAll('input[type="checkbox"][name^="transitions"]')
    
    checkboxes.forEach(checkbox => {
      if (!checkbox.disabled) {
        checkbox.addEventListener('change', this.onCheckboxChange.bind(this))
      }
    })
  }

  onCheckboxChange(event) {
    // Optional: Could add visual feedback here
  }

  async submitChanges(event) {
    event.preventDefault()
    
    const changedTransitions = this.getChangedTransitions()
    
    if (Object.keys(changedTransitions).length === 0) {
      // No changes, redirect as normal
      this.redirectToReferer()
      return
    }

    // Prepare JSON payload with only the changed transitions
    const payload = {
      role_id: this.getRoleIds(),
      tracker_id: this.getTrackerIds(),
      used_statuses_only: this.getUsedStatusesOnly(),
      transitions: changedTransitions,
      delta_update: true  // Flag to indicate this is a delta update
    }

    try {
      const response = await patch(this.formTarget.action, {
        body: JSON.stringify(payload),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      if (response.ok) {
        const result = await response.json()
        // Show success message (could be improved with better UI feedback)
        if (result.status === 'success') {
          this.redirectToReferer()
        }
      } else {
        console.error('Error updating workflow:', response.statusText)
        // Fallback to standard form submission
        this.formTarget.submit()
      }
    } catch (error) {
      console.error('Error updating workflow:', error)
      // Fallback to standard form submission
      this.formTarget.submit()
    }
  }

  getChangedTransitions() {
    const currentState = this.captureCurrentState()
    const changedTransitions = {}

    // Get all checkboxes and build the full current transitions state
    // but only include transitions that have changed
    const hasChanges = Object.keys(currentState).some(name => {
      return this.originalState[name] !== currentState[name]
    })

    if (!hasChanges) {
      return {}
    }

    // Build full transitions state for changed areas
    // We need to send complete transition data for replace_transitions to work correctly
    const transitionsByStatus = this.groupTransitionsByStatus(currentState)
    
    // Only include status groups that have changes
    Object.keys(transitionsByStatus).forEach(oldStatusId => {
      Object.keys(transitionsByStatus[oldStatusId]).forEach(newStatusId => {
        const transitions = transitionsByStatus[oldStatusId][newStatusId]
        const originalKey = `transitions[${oldStatusId}][${newStatusId}]`
        
        // Check if any transition in this group changed
        const hasStatusChange = Object.keys(transitions).some(rule => {
          const fullKey = `${originalKey}[${rule}]`
          return this.originalState[fullKey] !== currentState[fullKey]
        })
        
        if (hasStatusChange) {
          if (!changedTransitions[oldStatusId]) {
            changedTransitions[oldStatusId] = {}
          }
          changedTransitions[oldStatusId][newStatusId] = transitions
        }
      })
    })

    return changedTransitions
  }

  groupTransitionsByStatus(state) {
    const grouped = {}
    
    Object.keys(state).forEach(name => {
      const match = name.match(/transitions\[(\d+)\]\[(\d+)\]\[(\w+)\]/)
      if (match) {
        const [, oldStatusId, newStatusId, type] = match
        
        if (!grouped[oldStatusId]) {
          grouped[oldStatusId] = {}
        }
        if (!grouped[oldStatusId][newStatusId]) {
          grouped[oldStatusId][newStatusId] = {}
        }
        
        grouped[oldStatusId][newStatusId][type] = state[name] ? '1' : '0'
      }
    })
    
    return grouped
  }

  getRoleIds() {
    const roleInputs = this.formTarget.querySelectorAll('input[name="role_id[]"]')
    return Array.from(roleInputs).map(input => input.value)
  }

  getTrackerIds() {
    const trackerInputs = this.formTarget.querySelectorAll('input[name="tracker_id[]"]')
    return Array.from(trackerInputs).map(input => input.value)
  }

  getUsedStatusesOnly() {
    const usedStatusesInput = this.formTarget.querySelector('input[name="used_statuses_only"]')
    return usedStatusesInput ? usedStatusesInput.value : '1'
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }

  redirectToReferer() {
    // Use the same redirect logic as the controller
    const currentUrl = new URL(window.location)
    const editUrl = new URL(this.formTarget.action.replace(/\/workflows$/, '/workflows/edit'), window.location.origin)
    
    // Copy current parameters to maintain state
    currentUrl.searchParams.forEach((value, key) => {
      if (['role_id', 'tracker_id', 'used_statuses_only'].includes(key)) {
        editUrl.searchParams.set(key, value)
      }
    })
    
    window.location.href = editUrl.toString()
  }
}