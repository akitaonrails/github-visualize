import { Controller } from "@hotwired/stimulus"

// Day-by-hour commit heatmap. Cells fade in hour by hour in chronological
// order, with the commit counter climbing in sync with the reveal.
export default class extends Controller {
  static targets = ["canvas", "counter"]
  static values = { data: Object }

  // Keep in sync with ApplicationHelper::HEAT_STOPS.
  static stops = [
    [45, 27, 78], [126, 34, 206], [192, 38, 211],
    [236, 72, 153], [249, 115, 22], [250, 204, 21]
  ]

  // How many cells are fading in at any moment during the sweep.
  static fadeSpan = 30

  connect() {
    this.numberFormat = new Intl.NumberFormat()
    this.resize = () => this.draw(this.progress ?? 0)
    window.addEventListener("resize", this.resize)
    this.draw(0)
    this.playWhenVisible()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.resize)
    cancelAnimationFrame(this.frame)
  }

  // Defer the replay until the chart scrolls into view.
  playWhenVisible() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.intersectionRatio >= 0.2)) {
        this.observer.disconnect()
        this.replay()
      }
    }, { threshold: 0.2 })
    this.observer.observe(this.element)
  }

  replay() {
    cancelAnimationFrame(this.frame)
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.progress = 1
      this.draw(1)
      return
    }
    const duration = 3000
    const start = performance.now()
    const tick = (now) => {
      this.progress = Math.min((now - start) / duration, 1)
      this.draw(this.progress)
      if (this.progress < 1) this.frame = requestAnimationFrame(tick)
    }
    this.frame = requestAnimationFrame(tick)
  }

  draw(progress) {
    const { rows, max } = this.dataValue
    if (!rows?.length) return

    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    const width = canvas.clientWidth
    const labelWidth = 64
    const headerHeight = 18
    const gap = 3
    const cellWidth = (width - labelWidth - gap * 23) / 24
    const cellHeight = 13
    const height = headerHeight + rows.length * (cellHeight + gap)

    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.height = `${height}px`
    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, width, height)

    ctx.fillStyle = "#525252"
    ctx.font = "10px ui-monospace, monospace"
    for (const hour of [0, 6, 12, 18]) {
      ctx.fillText(this.hourLabel(hour), labelWidth + hour * (cellWidth + gap), 10)
    }

    const totalCells = rows.length * 24
    const fadeSpan = this.constructor.fadeSpan
    // The sweep runs past totalCells by fadeSpan so the last cells finish fading.
    const sweep = progress * (totalCells + fadeSpan)
    let revealedCommits = 0

    rows.forEach((row, rowIndex) => {
      const y = headerHeight + rowIndex * (cellHeight + gap)
      ctx.fillStyle = "#737373"
      ctx.fillText(row.label, 0, y + cellHeight - 3)

      row.counts.forEach((count, hour) => {
        const index = rowIndex * 24 + hour
        const alpha = Math.min(Math.max((sweep - index) / fadeSpan, 0), 1)
        if (alpha <= 0) return
        if (alpha >= 0.5) revealedCommits += count

        ctx.globalAlpha = alpha
        ctx.fillStyle = this.heatColor(count, max)
        ctx.beginPath()
        ctx.roundRect(labelWidth + hour * (cellWidth + gap), y, cellWidth, cellHeight, 2)
        ctx.fill()
        ctx.globalAlpha = 1
      })
    })

    this.updateCounter(progress, revealedCommits)
  }

  updateCounter(progress, revealedCommits) {
    if (!this.hasCounterTarget) return
    const total = this.dataValue.total ?? 0
    this.counterTarget.textContent = this.numberFormat.format(progress >= 1 ? total : revealedCommits)
  }

  hourLabel(hour) {
    if (hour === 0) return "12am"
    if (hour === 12) return "12pm"
    return hour < 12 ? `${hour}am` : `${hour - 12}pm`
  }

  heatColor(value, max) {
    if (value === 0 || max === 0) return "#17131f"
    const stops = this.constructor.stops
    const t = Math.sqrt(value / max) * (stops.length - 1)
    const index = Math.min(Math.floor(t), stops.length - 2)
    const fraction = t - index
    const channel = (i) => Math.round(stops[index][i] + (stops[index + 1][i] - stops[index][i]) * fraction)
    return `rgb(${channel(0)}, ${channel(1)}, ${channel(2)})`
  }
}
