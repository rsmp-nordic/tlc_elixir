// Drag handler for TLC program cell editing

export function setupDragHandlers() {
  console.log("Setting up drag handlers");
  
  let isDragging = false;
  let startCell = null;
  let dragTargets = new Set();
  
  // Listen for mousedown on the document to catch all clicks
  document.addEventListener('mousedown', (e) => {
    const cell = e.target.closest('[phx-mousedown="drag_start"]');
    if (cell) {
      console.log("Drag started on cell:", cell);
      isDragging = true;
      startCell = cell;
      
      // Add visual feedback immediately
      cell.classList.add('outline', 'outline-2', 'outline-yellow-500');
      
      // Store start values
      const cycle = cell.getAttribute('phx-value-cycle');
      const group = cell.getAttribute('phx-value-group');
      const signal = cell.getAttribute('phx-value-current_signal');
      
      console.log(`Starting drag: cycle=${cycle}, group=${group}, signal=${signal}`);
      
      // Prevent text selection
      e.preventDefault();
    }
  });
  
  // Add visual feedback during drag
  document.addEventListener('mouseover', (e) => {
    if (isDragging && startCell) {
      const cell = e.target.closest('[phx-mousedown="drag_start"]');
      if (cell && cell.getAttribute('phx-value-group') === startCell.getAttribute('phx-value-group')) {
        cell.classList.add('outline', 'outline-2', 'outline-white');
        dragTargets.add(cell);
      }
    }
  });
  
  document.addEventListener('mouseout', (e) => {
    if (isDragging) {
      const cell = e.target.closest('[phx-mousedown="drag_start"]');
      if (cell && cell !== startCell) {
        cell.classList.remove('outline', 'outline-2', 'outline-white');
      }
    }
  });
  
  // Listen for mouseup anywhere in the document
  document.addEventListener('mouseup', (e) => {
    if (isDragging && startCell) {
      const endCell = e.target.closest('[phx-mousedown="drag_start"]');
      
      if (endCell && 
          startCell.getAttribute('phx-value-group') === endCell.getAttribute('phx-value-group')) {
        
        // Get values needed for the operation
        const signal = startCell.getAttribute('phx-value-current_signal');
        const startCycle = startCell.getAttribute('phx-value-cycle');
        const endCycle = endCell.getAttribute('phx-value-cycle');
        const group = endCell.getAttribute('phx-value-group');
        
        console.log(`Sending drag operation: from cycle ${startCycle} to ${endCycle}, group ${group}, signal ${signal}`);
        
        // Find the LiveView container
        const liveViewHook = document.getElementById('tlc-container');
        
        if (liveViewHook) {
          console.log("Found LiveView container, dispatching custom event");
          
          // Create and dispatch a custom event the LiveView can listen for
          const event = new CustomEvent("phx:event", {
            bubbles: true,
            cancelable: true,
            detail: {
              type: "form",
              event: "drag_end",
              data: {
                cycle: endCycle,
                group: group,
                start_cycle: startCycle,
                signal: signal
              }
            }
          });
          
          liveViewHook.dispatchEvent(event);
        } else {
          console.error("LiveView container not found, falling back to direct click");
          
          // Fallback: If we can't find the LiveView, send a series of click events instead
          for (let cycle = Math.min(startCycle, endCycle); cycle <= Math.max(startCycle, endCycle); cycle++) {
            const targetCell = document.querySelector(`[phx-mousedown="drag_start"][phx-value-cycle="${cycle}"][phx-value-group="${group}"]`);
            if (targetCell) {
              // Trigger a click event to update the signal
              targetCell.click();
            }
          }
        }
      }
      
      // Clean up
      isDragging = false;
      startCell.classList.remove('outline', 'outline-2', 'outline-yellow-500');
      startCell = null;
      
      // Remove visual indicators from all cells
      document.querySelectorAll('[phx-mousedown="drag_start"]').forEach(cell => {
        cell.classList.remove('outline', 'outline-2', 'outline-white', 'outline-yellow-500');
      });
      
      dragTargets.clear();
    }
  });
  
  // Cancel drag if ESC key is pressed
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isDragging) {
      isDragging = false;
      startCell = null;
      
      // Remove visual indicators
      const cells = document.querySelectorAll('[phx-mousedown="drag_start"]');
      cells.forEach(cell => {
        cell.classList.remove('outline', 'outline-2', 'outline-white');
      });
      
      dragTargets.clear();
    }
  });
  
  // Helper functions for program editing
  window.dispatchSkipEvent = function(cycle, duration) {
    document.dispatchEvent(new CustomEvent('phx:set_skip', {
      detail: { cycle, duration }
    }));
  };
  
  window.dispatchWaitEvent = function(cycle, duration) {
    document.dispatchEvent(new CustomEvent('phx:set_wait', {
      detail: { cycle, duration }
    }));
  };
  
  document.addEventListener('phx:set_skip', (e) => {
    const { cycle, duration } = e.detail;
    const event = new CustomEvent('phx:event', {
      bubbles: true,
      cancelable: true,
      detail: {
        type: 'form',
        event: 'set_skip',
        data: {
          cycle,
          duration
        }
      }
    });
    document.dispatchEvent(event);
  });
  
  document.addEventListener('phx:set_wait', (e) => {
    const { cycle, duration } = e.detail;
    const event = new CustomEvent('phx:event', {
      bubbles: true,
      cancelable: true,
      detail: {
        type: 'form',
        event: 'set_wait',
        data: {
          cycle,
          duration
        }
      }
    });
    document.dispatchEvent(event);
  });
}
