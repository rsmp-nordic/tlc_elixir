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
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import { setupSwitchDragHandlers } from "./hooks/switch_drag"
import { setupSignalDragHandlers } from "./hooks/signal_drag"
import { setupInputHandlers } from "./hooks/input_handlers"
import { setupPromptHandlers } from "./hooks/prompt_handlers"

// Define hooks for LiveView
let Hooks = {}
Hooks.DragHandler = {
  mounted() {
    this.dragging = false;
    this.dragStart = null;
    this.dragSignal = null;
    this.switchDragging = false;

    this.el.addEventListener("mousedown", (e) => {
      // Ensure we only handle mousedown on signal cells
      const signalCell = e.target.closest("[data-cycle][data-group][data-signal]");
      if (signalCell) {
        this.dragging = true;
        this.dragStart = {
          cycle: parseInt(signalCell.dataset.cycle),
          group: parseInt(signalCell.dataset.group),
          signal: signalCell.dataset.signal
        };
        this.dragSignal = signalCell.dataset.signal;

        // Notify LiveView of drag start
        this.pushEvent("drag_start", {
          cycle: signalCell.dataset.cycle,
          group: signalCell.dataset.group,
          signal: signalCell.dataset.signal
        });

        // Prevent text selection during drag
        e.preventDefault();
      }
      
      // Handle switch point dragging
      const switchCell = e.target.closest("[data-switch-cycle]");
      if (switchCell && switchCell.classList.contains("bg-gray-400")) {
        this.switchDragging = true;
        this.pushEvent("switch_drag_start", {});
        e.preventDefault();
      }
    });

    this.el.addEventListener("mousemove", (e) => {
      if (this.dragging) {
        const signalCell = e.target.closest("[data-cycle][data-group][data-signal]");
        if (signalCell && 
            parseInt(signalCell.dataset.group) === this.dragStart.group && 
            parseInt(signalCell.dataset.cycle) !== this.dragStart.cycle) {
          // Fill gap between drag start and current position
          this.pushEvent("fill_gap", {
            start_cycle: this.dragStart.cycle,
            end_cycle: signalCell.dataset.cycle,
            group: this.dragStart.group,
            signal: this.dragSignal
          });
        }
      }
      
      // Handle switch point hover during drag
      if (this.switchDragging) {
        const switchCell = e.target.closest("[data-switch-cycle]");
        // Let CSS handle the hover indication via the switch-dragging-active class
      }
    });

    // Using window for mouseup to catch events outside the element
    window.addEventListener("mouseup", (e) => {
      if (this.dragging) {
        const signalCell = e.target.closest("[data-cycle][data-group][data-signal]");
        if (signalCell) {
          this.pushEvent("drag_end", {
            cycle: signalCell.dataset.cycle,
            group: signalCell.dataset.group,
            start_cycle: this.dragStart.cycle,
            signal: this.dragSignal
          });
        } else {
          // We ended outside a signal cell, just notify end of drag
          this.pushEvent("drag_end", {
            cycle: this.dragStart.cycle,
            group: this.dragStart.group,
            start_cycle: this.dragStart.cycle,
            signal: this.dragSignal
          });
        }
        this.dragging = false;
        this.dragStart = null;
      }
      
      // Handle switch drag end
      if (this.switchDragging) {
        const switchCell = e.target.closest("[data-switch-cycle]");
        if (switchCell) {
          this.pushEvent("end_switch_drag", {
            cycle: switchCell.dataset.switchCycle
          });
        } else {
          this.pushEvent("end_switch_drag", {});
        }
        this.switchDragging = false;
      }
    });
  }
};

// Ensure the hook is properly registered
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Add a CSS class to indicate invalid transitions
document.styleSheets[0].insertRule(`
  .program-cell-invalid {
    position: relative;
  }
`, 0);

document.styleSheets[0].insertRule(`
  .program-cell-invalid::after {
    content: "!";
    position: absolute;
    top: 0;
    right: 0;
    background-color: red;
    color: white;
    width: 12px;
    height: 12px;
    font-size: 8px;
    line-height: 12px;
    text-align: center;
    border-radius: 50%;
  }
`, 0);

