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

// Define hooks for LiveView
const Hooks = {
  DragHandler: {
    mounted() {
      console.log("DragHandler hook mounted");
      let isDragging = false;
      let startCell = null;
      let lastVisitedCycle = null;
      let visitedCycles = new Set(); // Track all cycles we've visited
      
      this.el.addEventListener('mousedown', (e) => {
        const cell = e.target.closest('[phx-mousedown="drag_start"]');
        if (cell && cell.hasAttribute('phx-value-current_signal')) {
          console.log("Drag started");
          isDragging = true;
          startCell = cell;
          
          // Store initial values
          const cycle = parseInt(cell.getAttribute('phx-value-cycle'));
          const group = cell.getAttribute('phx-value-group');
          const signal = cell.getAttribute('phx-value-current_signal');
          
          lastVisitedCycle = cycle;
          visitedCycles.clear();
          visitedCycles.add(cycle);
          
          // Prevent text selection
          e.preventDefault();
        }
      });
      
      // Add real-time updating during drag
      document.addEventListener('mouseover', (e) => {
        if (isDragging && startCell) {
          const cell = e.target.closest('[phx-mousedown="drag_start"]');
          if (cell && 
              cell.getAttribute('phx-value-group') === startCell.getAttribute('phx-value-group')) {
            
            const signal = startCell.getAttribute('phx-value-current_signal');
            const currentCycle = parseInt(cell.getAttribute('phx-value-cycle'));
            const group = cell.getAttribute('phx-value-group');
            
            // Only send update if this is a new cycle
            if (!visitedCycles.has(currentCycle)) {
              console.log(`Real-time update: cycle=${currentCycle}, group=${group}, signal=${signal}`);
              
              // Check if we've skipped any cycles (fast movement)
              const cycleDistance = Math.abs(currentCycle - lastVisitedCycle);
              
              if (cycleDistance > 1) {
                // We moved too fast - fill in the gap with signal_stretch
                console.log(`Fast movement detected! Filling gap from ${lastVisitedCycle} to ${currentCycle}`);
                
                this.pushEvent("fill_gap", {
                  start_cycle: lastVisitedCycle.toString(),
                  end_cycle: currentCycle.toString(),
                  group: group,
                  signal: signal
                });
              } else {
                // Normal update for just this cell
                this.pushEvent("update_cell_signal", {
                  cycle: currentCycle.toString(),
                  group: group,
                  signal: signal
                });
              }
              
              lastVisitedCycle = currentCycle;
              visitedCycles.add(currentCycle);
            }
          }
        }
      });
      
      document.addEventListener('mouseup', (e) => {
        if (isDragging && startCell) {
          // Clean up
          isDragging = false;
          startCell = null;
          lastVisitedCycle = null;
          visitedCycles.clear();
        }
      });
    }
  },
  
  NumberInputHandler: {
    mounted() {
      console.log("NumberInputHandler mounted for", this.el.dataset.field);
      
      // Listen for any changes including keyboard, mouse clicks, arrow buttons, etc.
      this.el.addEventListener('input', (e) => {
        const field = this.el.dataset.field;
        const value = this.el.value;
        
        console.log(`Input changed: ${field} = ${value}`);
        
        // Send update to server
        if (field === "length") {
          this.pushEvent("update_program_length", { value });
        } else if (field === "offset") {
          this.pushEvent("update_program_offset", { value });
        }
      });
    }
  },
  
  PromptHandler: {
    mounted() {
      this.handleEvent("open_skip_prompt", ({cycle, current_duration}) => {
        const duration = prompt(`Enter skip duration (0 to remove):`, current_duration);
        if (duration !== null) {
          this.pushEvent("set_skip", {cycle, duration});
        }
      });

      this.handleEvent("open_wait_prompt", ({cycle, current_duration}) => {
        const duration = prompt(`Enter wait duration (0 to remove):`, current_duration);
        if (duration !== null) {
          this.pushEvent("set_wait", {cycle, duration});
        }
      });
    }
  },

  NumberInputHook: {
    mounted() {
      console.log("NumberInputHook mounted", this.el);
      
      this.el.addEventListener("change", (e) => {
        console.log("Number input changed:", this.el.value);
        
        // Send the new value to the server
        this.pushEvent("update_program_length", {
          value: this.el.value
        });
      });
      
      // Also catch input events which handles typing
      this.el.addEventListener("input", (e) => {
        console.log("Number input event:", this.el.value);
      });
    }
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
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

