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
    const trackWidth = width - labelWidth - 28
    const scanX = labelWidth + trackWidth * progress
    const fadeWidth = 24 // px behind the scan bar over which ticks reach full color
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
        const x = labelWidth + ((run.t - from) / span) * trackWidth
        // Ticks ahead of the scan bar sit dim; they light up as it passes.
        const lit = Math.min(Math.max((scanX - x) / fadeWidth, 0), 1)
        ctx.globalAlpha = 0.15 + 0.85 * lit
        ctx.fillStyle = colors[run.state]
        ctx.fillRect(x, y + 6, 2.5, laneHeight - 12)
        ctx.globalAlpha = 1
      }

      if (progress >= 1 && lane.green) {
        ctx.fillStyle = colors.green
        ctx.font = "13px ui-monospace, monospace"
        ctx.fillText("✓", labelWidth + trackWidth + 10, y + laneHeight / 2 + 5)
      }
    })

    if (progress > 0 && progress < 1) {
      const gradient = ctx.createLinearGradient(scanX - 14, 0, scanX, 0)
      gradient.addColorStop(0, "rgba(255, 255, 255, 0)")
      gradient.addColorStop(1, "rgba(255, 255, 255, 0.25)")
      ctx.fillStyle = gradient
      ctx.fillRect(scanX - 14, 0, 14, height)
      ctx.fillStyle = "rgba(255, 255, 255, 0.9)"
      ctx.fillRect(scanX, 0, 1.5, height)
    }
  }

  truncate(text, length) {
    return text.length > length ? `${text.slice(0, length - 1)}…` : text
  }
}
