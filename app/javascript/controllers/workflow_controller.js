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
    
    // Handle checkboxes
    const checkboxes = this.formTarget.querySelectorAll('input[type="checkbox"][name^="transitions"]')
    checkboxes.forEach(checkbox => {
      if (!checkbox.disabled) {
        state[checkbox.name] = checkbox.checked
      }
    })
    
    // Handle select dropdowns (used when there are mixed role/tracker combinations)
    const selects = this.formTarget.querySelectorAll('select[name^="transitions"]')
    selects.forEach(select => {
      if (select.value !== 'no_change') {
        state[select.name] = select.value === '1'
      }
    })
    
    return state
  }

  setupChangeListeners() {
    // Handle checkboxes
    const checkboxes = this.formTarget.querySelectorAll('input[type="checkbox"][name^="transitions"]')
    checkboxes.forEach(checkbox => {
      if (!checkbox.disabled) {
        checkbox.addEventListener('change', this.onInputChange.bind(this))
      }
    })
    
    // Handle select dropdowns
    const selects = this.formTarget.querySelectorAll('select[name^="transitions"]')
    selects.forEach(select => {
      select.addEventListener('change', this.onInputChange.bind(this))
    })
  }

  onInputChange(event) {
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

    // Get all form inputs and build the full current transitions state
    // but only include transitions that have changed
    const hasChanges = Object.keys(currentState).some(name => {
      return this.originalState[name] !== currentState[name]
    })

    // Also check for changes from selects that were originally "no_change"
    const selects = this.formTarget.querySelectorAll('select[name^="transitions"]')
    const hasSelectChanges = Array.from(selects).some(select => {
      const originalHadValue = this.originalState.hasOwnProperty(select.name)
      const currentValue = select.value
      return currentValue !== 'no_change' && (!originalHadValue || this.originalState[select.name] !== (currentValue === '1'))
    })

    if (!hasChanges && !hasSelectChanges) {
      return {}
    }

    // Build full transitions state for changed areas
    // We need to send complete transition data for replace_transitions to work correctly
    const transitionsByStatus = this.groupTransitionsByStatus(currentState)
    
    // Add select elements that changed from "no_change"
    selects.forEach(select => {
      if (select.value !== 'no_change') {
        const match = select.name.match(/transitions\[(\d+)\]\[(\d+)\]\[(\w+)\]/)
        if (match) {
          const [, oldStatusId, newStatusId, type] = match
          
          if (!transitionsByStatus[oldStatusId]) {
            transitionsByStatus[oldStatusId] = {}
          }
          if (!transitionsByStatus[oldStatusId][newStatusId]) {
            transitionsByStatus[oldStatusId][newStatusId] = {}
          }
          
          transitionsByStatus[oldStatusId][newStatusId][type] = select.value
        }
      }
    })
    
    // Only include status groups that have changes
    Object.keys(transitionsByStatus).forEach(oldStatusId => {
      Object.keys(transitionsByStatus[oldStatusId]).forEach(newStatusId => {
        const transitions = transitionsByStatus[oldStatusId][newStatusId]
        const originalKey = `transitions[${oldStatusId}][${newStatusId}]`
        
        // Check if any transition in this group changed
        const hasStatusChange = Object.keys(transitions).some(rule => {
          const fullKey = `${originalKey}[${rule}]`
          const currentValue = transitions[rule]
          const originalValue = this.originalState[fullKey]
          
          // Handle different value types
          if (typeof originalValue === 'boolean' && typeof currentValue === 'string') {
            return originalValue !== (currentValue === '1')
          } else if (typeof originalValue === 'string' && typeof currentValue === 'boolean') {
            return (originalValue === '1') !== currentValue
          } else {
            return originalValue !== currentValue
          }
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
        
        // Handle both boolean (from checkboxes) and string (from selects) values
        const value = state[name]
        if (typeof value === 'boolean') {
          grouped[oldStatusId][newStatusId][type] = value ? '1' : '0'
        } else if (typeof value === 'string') {
          grouped[oldStatusId][newStatusId][type] = value
        } else {
          grouped[oldStatusId][newStatusId][type] = value ? '1' : '0'
        }
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