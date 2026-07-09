import { Controller } from "@hotwired/stimulus"

// Typeahead for the add-repository field, backed by /suggestions
// (the GitHub repos of the configured owner, minus already-monitored ones).
export default class extends Controller {
  static targets = ["input", "list"]
  static values = { url: String }

  connect() {
    this.selectedIndex = -1
    this.outsideClick = (event) => {
      if (!this.element.contains(event.target)) this.hide()
    }
    document.addEventListener("click", this.outsideClick)
  }

  disconnect() {
    document.removeEventListener("click", this.outsideClick)
    clearTimeout(this.debounce)
  }

  search() {
    clearTimeout(this.debounce)
    this.debounce = setTimeout(() => this.fetchSuggestions(), 250)
  }

  async fetchSuggestions() {
    const query = this.inputTarget.value.trim()
    let suggestions
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`,
        { headers: { Accept: "application/json" } })
      if (!response.ok) return this.hide()
      suggestions = await response.json()
    } catch {
      return this.hide()
    }
    this.renderList(suggestions)
  }

  renderList(suggestions) {
    this.selectedIndex = -1
    if (!suggestions.length) return this.hide()

    this.listTarget.replaceChildren(
      ...suggestions.map((repo) => {
        const item = document.createElement("button")
        item.type = "button"
        item.dataset.fullName = repo.full_name
        item.className = "block w-full text-left px-3 py-1.5 hover:bg-neutral-800 cursor-pointer"
        item.addEventListener("click", () => this.pick(repo.full_name))

        const name = document.createElement("span")
        name.className = "text-neutral-200"
        name.textContent = repo.display_name || repo.full_name

        item.append(name)
        if (repo.private) {
          const badge = document.createElement("span")
          badge.className = "ml-2 text-[10px] text-amber-400 border border-amber-900 rounded-full px-1.5"
          badge.textContent = "private"
          item.append(badge)
        }
        if (repo.description) {
          const description = document.createElement("span")
          description.className = "block text-[11px] text-neutral-500 truncate"
          description.textContent = repo.description
          item.append(description)
        }
        return item
      })
    )
    this.listTarget.classList.remove("hidden")
  }

  navigate(event) {
    const items = Array.from(this.listTarget.children)
    if (this.listTarget.classList.contains("hidden") || !items.length) return

    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.selectedIndex = (this.selectedIndex + step + items.length) % items.length
      items.forEach((item, index) =>
        item.classList.toggle("bg-neutral-800", index === this.selectedIndex))
    } else if (event.key === "Enter" && this.selectedIndex >= 0) {
      event.preventDefault()
      this.pick(items[this.selectedIndex].dataset.fullName)
    } else if (event.key === "Escape") {
      this.hide()
    }
  }

  pick(fullName) {
    this.inputTarget.value = fullName
    this.hide()
    this.inputTarget.form.requestSubmit()
  }

  hide() {
    this.listTarget.classList.add("hidden")
    this.selectedIndex = -1
  }
}
