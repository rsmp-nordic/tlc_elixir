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
import { setupSignalDragHandlers } from "./hooks/signal_drag"
import { setupInputHandlers } from "./hooks/input_handlers"
import { setupPromptHandlers } from "./hooks/prompt_handlers"

// Define hooks for LiveView
let Hooks = {}
Hooks.DragHandler = {
  mounted() {
    this.dragging = false
    this.dragStart = null
    this.dragSignal = null

    this.el.addEventListener("mousedown", (e) => {
      const signalCell = e.target.closest("[data-cycle][data-group][data-signal]")
      if (signalCell) {
        this.dragging = true
        this.dragStart = {
          cycle: parseInt(signalCell.dataset.cycle),
          group: parseInt(signalCell.dataset.group),
          signal: signalCell.dataset.signal
        }
        this.dragSignal = signalCell.dataset.signal
        this.pushEvent("drag_start", {
          cycle: signalCell.dataset.cycle,
          group: signalCell.dataset.group,
          signal: signalCell.dataset.signal
        })
        e.preventDefault()
      }
    })

    this.el.addEventListener("mousemove", (e) => {
      if (!this.dragging) return
      const signalCell = e.target.closest("[data-cycle][data-group][data-signal]")
      if (
        signalCell &&
        parseInt(signalCell.dataset.group) === this.dragStart.group &&
        parseInt(signalCell.dataset.cycle) !== this.dragStart.cycle
      ) {
        this.pushEvent("fill_gap", {
          start_cycle: this.dragStart.cycle,
          end_cycle: signalCell.dataset.cycle,
          group: this.dragStart.group,
          signal: this.dragSignal
        })
      }
    })

    window.addEventListener("mouseup", (e) => {
      if (!this.dragging) return
      const signalCell = e.target.closest("[data-cycle][data-group][data-signal]")
      if (signalCell) {
        this.pushEvent("drag_end", {
          cycle: signalCell.dataset.cycle,
          group: signalCell.dataset.group,
          start_cycle: this.dragStart.cycle,
          signal: this.dragSignal
        })
      } else {
        this.pushEvent("drag_end", {
          cycle: this.dragStart.cycle,
          group: this.dragStart.group,
          start_cycle: this.dragStart.cycle,
          signal: this.dragSignal
        })
      }
      this.dragging = false
      this.dragStart = null
    })

    // Click to set switch
    this.el.addEventListener("click", (e) => {
      const switchCell = e.target.closest("[data-switch-cycle]")
      if (switchCell) {
        this.pushEvent("set_switch", { cycle: switchCell.dataset.switchCycle })
      }
    })
  }
}

// Single LiveSocket init
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

// Topbar + connect
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _ => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _ => topbar.hide())
liveSocket.connect()
window.liveSocket = liveSocket
