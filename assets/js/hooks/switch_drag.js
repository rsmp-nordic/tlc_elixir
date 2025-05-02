export function setupSwitchDragHandlers(hook) {
  let isSwitchDragging = false;
  let switchPoint = null;
  
  // Start dragging the switch point
  document.addEventListener('mousedown', (e) => {
    const switchCell = e.target.closest('[phx-mousedown="switch_drag_start"]');
    
    if (switchCell) {
      console.log("Switch point drag started");
      isSwitchDragging = true;
      switchPoint = switchCell;
      
      // Notify server about drag start to set switch_dragging assign
      hook.pushEvent("switch_drag_start", {});
      
      // Prevent text selection
      e.preventDefault();
    }
  });
  
  // Handle ending the dragging operation
  document.addEventListener('mouseup', (e) => {
    if (isSwitchDragging) {
      console.log("Switch drag ending");
      
      // Find target cell
      const targetCell = e.target.closest('[data-switch-cycle]');
      if (targetCell && targetCell !== switchPoint) {
        const endCycle = targetCell.getAttribute('data-switch-cycle');
        
        console.log(`Moving switch point to ${endCycle}`);
        // Send final position with end_switch_drag event
        hook.pushEvent("end_switch_drag", {
          cycle: endCycle
        });
      } else {
        // No valid target, just end the drag without changes
        hook.pushEvent("end_switch_drag", {});
      }
      
      isSwitchDragging = false;
      switchPoint = null;
    }
  });
  
  // Also add escape key handler to cancel drag
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isSwitchDragging) {
      console.log("Canceling switch drag with Escape key");
      
      // Just end the drag without sending a new position
      hook.pushEvent("end_switch_drag", {});
      
      isSwitchDragging = false;
      switchPoint = null;
    }
  });
}
