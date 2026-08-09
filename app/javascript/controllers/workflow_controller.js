import { Controller } from "@hotwired/stimulus"
import { patch } from "@rails/request.js"

export default class extends Controller {
  static targets = ["form"]

  async submitChanges(event) {
    event.preventDefault()
    
    const changedTransitions = this.getChangedTransitions()
    
    // If no changes, just redirect back
    if (Object.keys(changedTransitions).length === 0) {
      this.redirectToReferer()
      return
    }

    const payload = {
      role_id: this.getRoleIds(),
      tracker_id: this.getTrackerIds(),
      used_statuses_only: this.getUsedStatusesOnly(),
      transitions: changedTransitions
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
        this.redirectToReferer()
      } else {
        // Log error and stay on page for debugging
        console.error('Workflow update failed:', response.status, response.statusText)
        try {
          const errorData = await response.json()
          console.error('Error details:', errorData)
        } catch (e) {
          console.error('Could not parse error response')
        }
      }
    } catch (error) {
      console.error('Network error during workflow update:', error)
    }
  }

  getChangedTransitions() {
    const transitions = {}
    
    // Get all checkboxes that have changed from their default state
    const checkboxes = this.formTarget.querySelectorAll('input[type="checkbox"][name^="transitions"]')
    checkboxes.forEach(checkbox => {
      if (!checkbox.disabled && checkbox.defaultChecked !== checkbox.checked) {
        const match = checkbox.name.match(/transitions\[(\d+)\]\[(\d+)\]\[(\w+)\]/)
        if (match) {
          const [, oldStatusId, newStatusId, type] = match
          
          if (!transitions[oldStatusId]) {
            transitions[oldStatusId] = {}
          }
          if (!transitions[oldStatusId][newStatusId]) {
            transitions[oldStatusId][newStatusId] = {}
          }
          
          transitions[oldStatusId][newStatusId][type] = checkbox.checked ? '1' : '0'
        }
      }
    })
    
    // Get all selects that have changed from their default value
    const selects = this.formTarget.querySelectorAll('select[name^="transitions"]')
    selects.forEach(select => {
      if (select.defaultValue !== select.value && select.value !== 'no_change') {
        const match = select.name.match(/transitions\[(\d+)\]\[(\d+)\]\[(\w+)\]/)
        if (match) {
          const [, oldStatusId, newStatusId, type] = match
          
          if (!transitions[oldStatusId]) {
            transitions[oldStatusId] = {}
          }
          if (!transitions[oldStatusId][newStatusId]) {
            transitions[oldStatusId][newStatusId] = {}
          }
          
          transitions[oldStatusId][newStatusId][type] = select.value
        }
      }
    })
    
    return transitions
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
    const currentUrl = new URL(window.location)
    const editUrl = new URL(this.formTarget.action.replace(/\/workflows$/, '/workflows/edit'), window.location.origin)
    
    currentUrl.searchParams.forEach((value, key) => {
      if (['role_id', 'tracker_id', 'used_statuses_only'].includes(key)) {
        editUrl.searchParams.set(key, value)
      }
    })
    
    window.location.href = editUrl.toString()
  }
}