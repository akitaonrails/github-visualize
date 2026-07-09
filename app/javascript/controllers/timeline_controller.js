import { Controller } from "@hotwired/stimulus"

// Commit timeline replay: additions (pink) and deletions (cyan) per bucket,
// with counters and a scrolling commit log, like the Bun post's git log chart.
export default class extends Controller {
  static targets = ["canvas", "commits", "lines", "deleted", "log"]
  static values = { data: Object }

  connect() {
    this.numberFormat = new Intl.NumberFormat()
    this.resize = () => this.render(this.progress ?? 1)
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
      this.render(1)
      return
    }
    const duration = 4000
    const start = performance.now()
    const tick = (now) => {
      this.progress = Math.min((now - start) / duration, 1)
      this.render(this.progress)
      if (this.progress < 1) this.frame = requestAnimationFrame(tick)
    }
    this.frame = requestAnimationFrame(tick)
  }

  render(progress) {
    this.drawBars(progress)
    this.updateCounters(progress)
    this.updateLog(progress)
  }

  drawBars(progress) {
    const { buckets } = this.dataValue
    if (!buckets?.length) return

    const canvas = this.canvasTarget
    const dpr = window.devicePixelRatio || 1
    const width = canvas.clientWidth
    const height = 220
    canvas.width = width * dpr
    canvas.height = height * dpr
    canvas.style.height = `${height}px`
    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, width, height)

    ctx.strokeStyle = "#262626"
    ctx.beginPath()
    ctx.moveTo(0, height - 0.5)
    ctx.lineTo(width, height - 0.5)
    ctx.stroke()

    const maxLines = Math.max(...buckets.map((bucket) => bucket.additions + bucket.deletions), 1)
    const barWidth = width / buckets.length
    const scanX = width * progress
    const fadeWidth = 30 // px behind the scan bar over which bars reach full color

    buckets.forEach((bucket, index) => {
      const x = index * barWidth
      const scale = (value) => Math.sqrt(value / maxLines) * (height - 8)
      const additionsHeight = scale(bucket.additions)
      const deletionsHeight = scale(bucket.deletions)

      // Bars ahead of the scan bar sit dim; they light up as it passes.
      const lit = Math.min(Math.max((scanX - x) / fadeWidth, 0), 1)
      ctx.globalAlpha = 0.12 + 0.88 * lit

      ctx.fillStyle = "#f472b6"
      ctx.fillRect(x, height - additionsHeight, Math.max(barWidth - 1, 1), additionsHeight)
      ctx.fillStyle = "#22d3ee"
      ctx.fillRect(x, height - deletionsHeight, Math.max((barWidth - 1) / 2, 1), deletionsHeight)
      ctx.globalAlpha = 1
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

  updateCounters(progress) {
    const { buckets, total_commits, total_additions, total_deletions } = this.dataValue
    if (!buckets?.length) return

    const visible = Math.ceil(buckets.length * progress)
    const partial = buckets.slice(0, visible).reduce(
      (sum, bucket) => ({
        commits: sum.commits + bucket.count,
        additions: sum.additions + bucket.additions,
        deletions: sum.deletions + bucket.deletions
      }),
      { commits: 0, additions: 0, deletions: 0 }
    )

    const done = progress >= 1
    this.commitsTarget.textContent = this.numberFormat.format(done ? total_commits : partial.commits)
    this.linesTarget.textContent = `+${this.numberFormat.format(done ? total_additions : partial.additions)}`
    this.deletedTarget.textContent = `-${this.numberFormat.format(done ? total_deletions : partial.deletions)}`
  }

  updateLog(progress) {
    const { log } = this.dataValue
    if (!log?.length) return

    const visible = Math.max(Math.ceil(log.length * progress), 1)
    const entries = log.slice(Math.max(visible - 6, 0), visible)

    this.logTarget.replaceChildren(
      ...entries.map((entry) => {
        const line = document.createElement("p")
        line.className = "truncate"

        const time = document.createElement("span")
        time.className = "text-neutral-600"
        time.textContent = `${entry.at}  `

        const message = document.createElement("span")
        message.className = "text-neutral-300"
        message.textContent = entry.message

        const additions = document.createElement("span")
        additions.className = "text-pink-400"
        additions.textContent = `  +${this.numberFormat.format(entry.additions)}`

        const deletions = document.createElement("span")
        deletions.className = "text-cyan-400"
        deletions.textContent = ` -${this.numberFormat.format(entry.deletions)}`

        line.append(time, message, additions, deletions)
        return line
      })
    )
  }
}
