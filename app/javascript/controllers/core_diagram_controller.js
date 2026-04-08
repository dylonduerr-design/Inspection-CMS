import { Controller } from "@hotwired/stimulus"

// Renders a horizontal bar chart of lanes with core positions plotted as dots.
// Each sublot is a section; lanes are colored bars, joints are gold bands between them.
export default class extends Controller {
  static targets = ["canvas"]
  static values = { data: Object }

  connect() {
    this._dotHitTargets = []
    this._tooltip = null
    this._boundMouseMove = this.handleMouseMove.bind(this)
    this._boundMouseLeave = this.handleMouseLeave.bind(this)

    // Delay initial draw to ensure layout is complete (handles hidden tabs, Turbo)
    requestAnimationFrame(() => {
      this.draw()
      this._resizeObserver = new ResizeObserver(() => this.draw())
      this._resizeObserver.observe(this.element)
      this.canvasTarget.addEventListener("mousemove", this._boundMouseMove)
      this.canvasTarget.addEventListener("mouseleave", this._boundMouseLeave)
    })
  }

  disconnect() {
    if (this._resizeObserver) this._resizeObserver.disconnect()
    this.canvasTarget.removeEventListener("mousemove", this._boundMouseMove)
    this.canvasTarget.removeEventListener("mouseleave", this._boundMouseLeave)
    this.removeTooltip()
  }

  dataValueChanged() { this.draw() }

  draw() {
    const canvas = this.canvasTarget
    const data = this.dataValue
    if (!data || !data.sublots) return

    const dpr = window.devicePixelRatio || 1
    const containerWidth = Math.max(300, this.element.clientWidth - 32) // padding, min 300px
    const leftMargin = 70
    const rightMargin = 20
    const topMargin = 10
    const bottomMargin = 30
    const jointHeight = 16
    const sublotGap = 28
    const sublotLabelHeight = 22
    const legendHeight = 40

    // Find max lane width to set height scale — lanes are drawn proportional to width_ft
    // Use a scale that makes a 12ft lane ~60px tall (visually readable for offset positioning)
    const widthScale = 5 // px per ft of lane width
    const minLaneHeight = 40

    // Calculate total canvas height
    let totalHeight = topMargin + legendHeight
    for (const sublot of data.sublots) {
      const laneCount = sublot.lanes.length
      const jointCount = Math.max(0, laneCount - 1)
      let sublotH = sublotLabelHeight + jointCount * jointHeight + sublotGap
      for (const lane of sublot.lanes) {
        sublotH += Math.max(minLaneHeight, lane.width_ft * widthScale)
      }
      totalHeight += sublotH
    }
    totalHeight += bottomMargin

    canvas.width = containerWidth * dpr
    canvas.height = totalHeight * dpr
    canvas.style.width = containerWidth + "px"
    canvas.style.height = totalHeight + "px"

    const ctx = canvas.getContext("2d")
    ctx.scale(dpr, dpr)
    ctx.clearRect(0, 0, containerWidth, totalHeight)

    // Reset hit targets for tooltip hover detection
    this._dotHitTargets = []

    // Find max lane length across all sublots for consistent scaling
    let maxLength = 0
    for (const sublot of data.sublots) {
      for (const lane of sublot.lanes) {
        if (lane.length_ft > maxLength) maxLength = lane.length_ft
      }
    }
    if (maxLength === 0) return

    const chartWidth = containerWidth - leftMargin - rightMargin
    const xScale = chartWidth / maxLength
    const bufferFt = data.buffer_ft || 0

    // Uniform lane color
    const laneColor = "#4B83C4"
    const laneColorBg = "#D6E4F0"
    const laneBorder = "#3A6EA5"
    const jointColor = "#F59E0B"
    const jointColorBg = "#FEF3C7"
    const matDotColor = "#DC2626"
    const jointDotColor = "#F97316"
    const bufferColor = "rgba(0,0,0,0.10)"

    // Draw legend
    this.drawLegend(ctx, containerWidth, topMargin, matDotColor, jointDotColor, laneColor)

    let y = topMargin + legendHeight

    for (const sublot of data.sublots) {
      // Sublot label
      ctx.fillStyle = "#374151"
      ctx.font = "bold 13px system-ui, -apple-system, sans-serif"
      ctx.textAlign = "left"
      ctx.fillText(`Sublot ${sublot.position}`, leftMargin, y + 14)
      y += sublotLabelHeight

      const lanes = sublot.lanes.sort((a, b) => a.position - b.position)

      for (let i = 0; i < lanes.length; i++) {
        const lane = lanes[i]
        const laneH = Math.max(minLaneHeight, lane.width_ft * widthScale)
        const barWidth = lane.length_ft * xScale
        const barX = leftMargin
        const barY = y

        // Lane bar background
        ctx.fillStyle = laneColorBg
        ctx.fillRect(barX, barY, barWidth, laneH)

        // Lane bar fill
        ctx.fillStyle = laneColor
        ctx.globalAlpha = 0.35
        ctx.fillRect(barX, barY, barWidth, laneH)
        ctx.globalAlpha = 1.0

        // Lane border
        ctx.strokeStyle = laneBorder
        ctx.lineWidth = 1
        ctx.strokeRect(barX, barY, barWidth, laneH)

        // Buffer zone
        if (bufferFt > 0) {
          const bufW = Math.min(bufferFt * xScale, barWidth)
          ctx.fillStyle = bufferColor
          ctx.fillRect(barX, barY, bufW, laneH)
          // Dashed buffer edge line
          ctx.setLineDash([3, 3])
          ctx.strokeStyle = "#999"
          ctx.lineWidth = 1
          ctx.beginPath()
          ctx.moveTo(barX + bufW, barY)
          ctx.lineTo(barX + bufW, barY + laneH)
          ctx.stroke()
          ctx.setLineDash([])
        }

        // Lane label (with width annotation)
        ctx.fillStyle = "#374151"
        ctx.font = "12px system-ui, -apple-system, sans-serif"
        ctx.textAlign = "right"
        ctx.fillText(`Lane ${lane.position}`, leftMargin - 8, barY + laneH / 2 + 1)
        ctx.fillStyle = "#6B7280"
        ctx.font = "10px system-ui, -apple-system, sans-serif"
        ctx.fillText(`${lane.width_ft}ft wide`, leftMargin - 8, barY + laneH / 2 + 14)

        // Draw mat cores on this lane — Y positioned by offset within lane width
        const laneCores = (sublot.cores || []).filter(
          c => c.type === "mat" && c.lane_position === lane.position
        )
        for (const core of laneCores) {
          const cx = barX + core.station_ft * xScale
          const offsetRatio = lane.width_ft > 0 ? core.offset_ft / lane.width_ft : 0.5
          const cy = barY + offsetRatio * laneH
          this.drawCoreDot(ctx, cx, cy, matDotColor, core.adjusted, core.mark)
          this._dotHitTargets.push({
            x: cx, y: cy, radius: 8,
            label: `${core.mark}${core.adjusted ? " *" : ""}`,
            lines: [
              `Station: ${core.station_ft.toFixed(1)} ft`,
              `Offset: ${core.offset_ft.toFixed(1)} ft`
            ]
          })
        }

        y += laneH

        // Draw joint band between this lane and next
        if (i < lanes.length - 1) {
          const nextLane = lanes[i + 1]
          const jointLength = Math.min(lane.length_ft, nextLane.length_ft)
          const jointWidth = jointLength * xScale
          const jointY = y

          ctx.fillStyle = jointColorBg
          ctx.fillRect(barX, jointY, jointWidth, jointHeight)
          ctx.fillStyle = jointColor
          ctx.globalAlpha = 0.45
          ctx.fillRect(barX, jointY + 2, jointWidth, jointHeight - 4)
          ctx.globalAlpha = 1.0

          // Joint label
          ctx.fillStyle = "#92400E"
          ctx.font = "11px system-ui, -apple-system, sans-serif"
          ctx.textAlign = "right"
          ctx.fillText(`J ${lane.position}-${nextLane.position}`, leftMargin - 8, jointY + jointHeight / 2 + 3)

          // Draw joint cores
          const jointCores = (sublot.cores || []).filter(
            c => c.type === "joint" && c.left_lane === lane.position && c.right_lane === nextLane.position
          )
          for (const core of jointCores) {
            const cx = barX + core.station_ft * xScale
            const cy = jointY + jointHeight / 2
            this.drawCoreDot(ctx, cx, cy, jointDotColor, core.adjusted, core.mark)
            this._dotHitTargets.push({
              x: cx, y: cy, radius: 8,
              label: `${core.mark}`,
              lines: [
                `Station: ${core.station_ft.toFixed(1)} ft`,
                `Joint: Lane ${lane.position} / ${nextLane.position}`
              ]
            })
          }

          y += jointHeight
        }
      }

      // X-axis ticks for this sublot
      this.drawXAxis(ctx, leftMargin, y + 2, chartWidth, maxLength, xScale)
      y += sublotGap
    }
  }

  drawCoreDot(ctx, cx, cy, color, adjusted, mark) {
    const radius = 5
    ctx.beginPath()
    ctx.arc(cx, cy, radius, 0, Math.PI * 2)
    ctx.fillStyle = color
    ctx.fill()
    ctx.strokeStyle = "#fff"
    ctx.lineWidth = 1.5
    ctx.stroke()

    if (adjusted) {
      ctx.fillStyle = "#fff"
      ctx.font = "bold 8px system-ui, sans-serif"
      ctx.textAlign = "center"
      ctx.fillText("*", cx, cy + 3)
    }
  }

  drawXAxis(ctx, x, y, width, maxLength, scale) {
    // Determine tick interval
    const intervals = [50, 100, 200, 500, 1000, 2000]
    let tickInterval = 100
    for (const iv of intervals) {
      if (maxLength / iv <= 10) { tickInterval = iv; break }
    }

    ctx.strokeStyle = "#D1D5DB"
    ctx.lineWidth = 1
    ctx.fillStyle = "#6B7280"
    ctx.font = "10px system-ui, -apple-system, sans-serif"
    ctx.textAlign = "center"

    for (let ft = 0; ft <= maxLength; ft += tickInterval) {
      const tx = x + ft * scale
      ctx.beginPath()
      ctx.moveTo(tx, y)
      ctx.lineTo(tx, y + 6)
      ctx.stroke()
      ctx.fillText(`${ft}`, tx, y + 16)
    }
  }

  drawLegend(ctx, canvasWidth, topY, matColor, jointDotColor, laneColor) {
    const legendX = canvasWidth - 320
    const legendY = topY

    ctx.font = "11px system-ui, -apple-system, sans-serif"
    ctx.textAlign = "left"

    // Mat core dot
    ctx.beginPath()
    ctx.arc(legendX, legendY + 8, 6, 0, Math.PI * 2)
    ctx.fillStyle = matColor
    ctx.fill()
    ctx.strokeStyle = "#fff"
    ctx.lineWidth = 1.5
    ctx.stroke()
    ctx.fillStyle = "#374151"
    ctx.fillText("Mat Core", legendX + 12, legendY + 12)

    // Joint core dot
    ctx.beginPath()
    ctx.arc(legendX + 95, legendY + 8, 6, 0, Math.PI * 2)
    ctx.fillStyle = jointDotColor
    ctx.fill()
    ctx.strokeStyle = "#fff"
    ctx.lineWidth = 1.5
    ctx.stroke()
    ctx.fillStyle = "#374151"
    ctx.fillText("Joint Core", legendX + 107, legendY + 12)

    // Buffer zone
    ctx.fillStyle = "rgba(0,0,0,0.10)"
    ctx.fillRect(legendX + 200, legendY + 2, 14, 12)
    ctx.strokeStyle = "#999"
    ctx.lineWidth = 1
    ctx.setLineDash([2, 2])
    ctx.strokeRect(legendX + 200, legendY + 2, 14, 12)
    ctx.setLineDash([])
    ctx.fillStyle = "#374151"
    ctx.fillText("Buffer Zone", legendX + 219, legendY + 12)
  }

  handleMouseMove(event) {
    const canvas = this.canvasTarget
    const rect = canvas.getBoundingClientRect()
    const dpr = window.devicePixelRatio || 1
    const mx = (event.clientX - rect.left)
    const my = (event.clientY - rect.top)

    let hit = null
    for (const dot of this._dotHitTargets) {
      const dx = mx - dot.x
      const dy = my - dot.y
      if (dx * dx + dy * dy <= dot.radius * dot.radius) {
        hit = dot
        break
      }
    }

    if (hit) {
      canvas.style.cursor = "pointer"
      this.showTooltip(event.clientX, event.clientY, hit)
    } else {
      canvas.style.cursor = ""
      this.removeTooltip()
    }
  }

  handleMouseLeave() {
    this.canvasTarget.style.cursor = ""
    this.removeTooltip()
  }

  showTooltip(clientX, clientY, dot) {
    if (!this._tooltip) {
      this._tooltip = document.createElement("div")
      this._tooltip.style.cssText = `
        position: fixed; z-index: 9999; pointer-events: none;
        background: #1F2937; color: #F9FAFB; border-radius: 6px;
        padding: 8px 12px; font-size: 12px; line-height: 1.5;
        font-family: system-ui, -apple-system, sans-serif;
        box-shadow: 0 4px 12px rgba(0,0,0,0.25);
        white-space: nowrap;
      `
      document.body.appendChild(this._tooltip)
    }

    const title = `<strong>${dot.label}</strong>`
    const details = dot.lines.join("<br>")
    this._tooltip.innerHTML = `${title}<br>${details}`
    this._tooltip.style.left = (clientX + 12) + "px"
    this._tooltip.style.top = (clientY - 10) + "px"
  }

  removeTooltip() {
    if (this._tooltip) {
      this._tooltip.remove()
      this._tooltip = null
    }
  }
}
