import { Controller } from "@hotwired/stimulus"

// Polls the repository's sync status endpoint while a sync is pending or
// running, live-updating the badge, then refreshes the page once it settles
// so the charts render with the new data.
export default class extends Controller {
  static targets = ["badge", "progress"]
  static values = {
    url: String,
    state: String,
    interval: { type: Number, default: 2000 }
  }

  connect() {
    if (this.active(this.stateValue)) this.schedule()
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  active(state) {
    return state === "pending" || state === "syncing"
  }

  schedule() {
    this.timer = setTimeout(() => this.poll(), this.intervalValue)
  }

  async poll() {
    let data
    try {
      const response = await fetch(this.urlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return this.schedule()
      data = await response.json()
    } catch {
      return this.schedule()
    }

    if (this.active(data.status)) {
      if (this.hasBadgeTarget) this.badgeTarget.textContent = data.status
      if (this.hasProgressTarget) {
        this.progressTarget.textContent = data.progress ? ` · ${data.progress}` : ""
      }
      this.schedule()
    } else if (window.Turbo) {
      window.Turbo.visit(window.location.href, { action: "replace" })
    } else {
      window.location.reload()
    }
  }
}
