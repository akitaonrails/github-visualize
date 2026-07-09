import { Controller } from "@hotwired/stimulus"

// Swaps the dashboard commit bars between their precomputed log and
// linear widths (data-log-width / data-linear-width on each bar).
export default class extends Controller {
  static targets = ["bar", "label"]

  toggle() {
    this.linear = !this.linear
    this.barTargets.forEach((bar) => {
      bar.style.width = this.linear ? bar.dataset.linearWidth : bar.dataset.logWidth
    })
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.linear ? "(linear scale)" : "(log scale)"
    }
  }
}
