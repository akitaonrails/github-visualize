import { Controller } from "@hotwired/stimulus"

// Client-side filter for the monitored-repo cards: hides any card whose
// "owner/name" (data-repo-name) doesn't contain the typed text. Every card is
// already on the page, so this never hits the server.
export default class extends Controller {
  static targets = ["field", "item", "empty"]

  filter() {
    const query = this.fieldTarget.value.trim().toLowerCase()
    let visible = 0

    this.itemTargets.forEach((item) => {
      const match = query === "" || item.dataset.repoName.includes(query)
      item.classList.toggle("hidden", !match)
      if (match) visible += 1
    })

    if (this.hasEmptyTarget) this.emptyTarget.classList.toggle("hidden", visible > 0)
  }
}
