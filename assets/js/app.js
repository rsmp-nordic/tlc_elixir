// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

const Hooks = {}
Hooks.DragHandler = {
  mounted() {
    this.dragging = false
    this.dragStart = null
    this.dragSignal = null

    this.onMouseDown = (e) => {
      const cell = e.target.closest("[data-cycle][data-group][data-signal]")
      if (!cell) return
      this.dragging = true
      this.dragSignal = cell.dataset.signal
      this.dragStart = {
        cycle: Number(cell.dataset.cycle),
        group: Number(cell.dataset.group),
        signal: cell.dataset.signal
      }
      this.pushEvent("drag_start", {
        cycle: cell.dataset.cycle,
        group: cell.dataset.group,
        signal: cell.dataset.signal
      })
      e.preventDefault()
    }

    this.onMouseMove = (e) => {
      if (!this.dragging) return
      const cell = e.target.closest("[data-cycle][data-group][data-signal]")
      if (
        cell &&
        Number(cell.dataset.group) === this.dragStart.group &&
        Number(cell.dataset.cycle) !== this.dragStart.cycle
      ) {
        this.pushEvent("fill_gap", {
          start_cycle: this.dragStart.cycle,
            end_cycle: cell.dataset.cycle,
            group: this.dragStart.group,
            signal: this.dragSignal
        })
      }
    }

    this.onMouseUp = (e) => {
      if (!this.dragging) return
      const cell = e.target.closest("[data-cycle][data-group][data-signal]")
      const target = cell
        ? {cycle: cell.dataset.cycle, group: cell.dataset.group}
        : {cycle: this.dragStart.cycle, group: this.dragStart.group}
      this.pushEvent("drag_end", {
        cycle: target.cycle,
        group: target.group,
        start_cycle: this.dragStart.cycle,
        signal: this.dragSignal
      })
      this.dragging = false
      this.dragStart = null
    }

    this.onClick = (e) => {
      const switchCell = e.target.closest("[data-switch-cycle]")
      if (switchCell) this.pushEvent("set_switch", {cycle: switchCell.dataset.switchCycle})
    }

    this.el.addEventListener("mousedown", this.onMouseDown)
    this.el.addEventListener("mousemove", this.onMouseMove)
    window.addEventListener("mouseup", this.onMouseUp)
    this.el.addEventListener("click", this.onClick)
  },
  destroyed() {
    this.el.removeEventListener("mousedown", this.onMouseDown)
    this.el.removeEventListener("mousemove", this.onMouseMove)
    window.removeEventListener("mouseup", this.onMouseUp)
    this.el.removeEventListener("click", this.onClick)
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Topbar + connect
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _ => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _ => topbar.hide())
liveSocket.connect()
window.liveSocket = liveSocket
