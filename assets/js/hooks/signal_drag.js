export function setupSignalDragHandlers(hook) {
  let isDragging = false;
  let startCell = null;
  let lastVisitedCycle = null;
  let visitedCycles = new Set(); 
  
  // Start drag operation
  document.addEventListener('mousedown', (e) => {
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
  
  // Track cells during drag
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
            
            hook.pushEvent("fill_gap", {
              start_cycle: lastVisitedCycle.toString(),
              end_cycle: currentCycle.toString(),
              group: group,
              signal: signal
            });
          } else {
            // Normal update for just this cell
            hook.pushEvent("update_cell_signal", {
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
  
  // End drag operation
  document.addEventListener('mouseup', (e) => {
    if (isDragging) {
      isDragging = false;
      startCell = null;
      lastVisitedCycle = null;
      visitedCycles.clear();
    }
  });
  
  // Cancel drag with Escape key
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
      if (isDragging) {
        isDragging = false;
        startCell = null;
        lastVisitedCycle = null;
        visitedCycles.clear();
      }
    }
  });
}
