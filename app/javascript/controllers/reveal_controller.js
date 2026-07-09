import { Controller } from "@hotwired/stimulus"

// Expand/collapse a hidden block, swapping the toggle label.
export default class extends Controller {
  static targets = ["content", "toggle"]
  static values = { more: String, less: String }

  toggle() {
    const hidden = this.contentTarget.classList.toggle("hidden")
    this.toggleTarget.textContent = hidden ? this.moreValue : this.lessValue
  }
}
