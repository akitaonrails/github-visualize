import { Controller } from "@hotwired/stimulus"

// Shared behavior for the replayable canvas charts: draw a ghost frame on
// connect, play once when ~20% of the chart scrolls into view, skip to the
// final frame under prefers-reduced-motion, redraw the current frame on
// resize. Subclasses implement render(progress) and may override `duration`.
export default class PlaybackController extends Controller {
  static duration = 3000

  connect() {
    this.resize = () => this.render(this.progress ?? 0)
    window.addEventListener("resize", this.resize)
    this.render(0)
    this.playWhenVisible()
  }

  disconnect() {
    this.observer?.disconnect()
    window.removeEventListener("resize", this.resize)
    cancelAnimationFrame(this.frame)
  }

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
      this.render(1)
      return
    }
    const start = performance.now()
    const tick = (now) => {
      this.progress = Math.min((now - start) / this.constructor.duration, 1)
      this.render(this.progress)
      if (this.progress < 1) this.frame = requestAnimationFrame(tick)
    }
    this.frame = requestAnimationFrame(tick)
  }
}
