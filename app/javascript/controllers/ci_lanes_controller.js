import { Controller } from "@hotwired/stimulus"

// One lane per workflow, one tick per run, revealed chronologically:
// the "race to green" chart from the Bun post.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this.resize = () => this.draw(this.progress ?? 1)
    window.addEventListener("resize", this.resize)
    this.replay()
  }

  disconnect() {
    window.removeEventListener("resize", this.resize)
    cancelAnimationFrame(this.frame)
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
    const { lanes, from, to } = this.dataValue
    if (!lanes?.length) return

    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    const width = canvas.clientWidth
    const laneHeight = 28
    const labelWidth = Math.min(220, width * 0.3)
    const height = lanes.length * laneHeight
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.height = `${height}px`
    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, width, height)

    const span = Math.max(to - from, 1)
    const cutoff = from + span * progress
    const trackWidth = width - labelWidth - 28
    const colors = { green: "#34d399", red: "#ef4444", other: "#525252" }

    lanes.forEach((lane, index) => {
      const y = index * laneHeight

      ctx.strokeStyle = "#1f1f1f"
      ctx.beginPath()
      ctx.moveTo(labelWidth, y + laneHeight / 2)
      ctx.lineTo(labelWidth + trackWidth, y + laneHeight / 2)
      ctx.stroke()

      ctx.fillStyle = "#a3a3a3"
      ctx.font = "11px ui-monospace, monospace"
      ctx.fillText(this.truncate(lane.name, 28), 0, y + laneHeight / 2 + 4)

      for (const run of lane.runs) {
        if (run.t > cutoff) break
        const x = labelWidth + ((run.t - from) / span) * trackWidth
        ctx.fillStyle = colors[run.state]
        ctx.fillRect(x, y + 6, 2.5, laneHeight - 12)
      }

      if (progress >= 1 && lane.green) {
        ctx.fillStyle = colors.green
        ctx.font = "13px ui-monospace, monospace"
        ctx.fillText("✓", labelWidth + trackWidth + 10, y + laneHeight / 2 + 5)
      }
    })
  }

  truncate(text, length) {
    return text.length > length ? `${text.slice(0, length - 1)}…` : text
  }
}
