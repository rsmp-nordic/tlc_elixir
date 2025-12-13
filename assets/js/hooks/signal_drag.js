export function setupSignalDragHandlers(hook) {
  // Local drag state
  let isDragging = false;
  let startCell = null;
  let lastVisitedCycle = null;
  let visitedCycles = new Set();

  // Start drag operation (scoped to the LiveView hook element)
  const onMouseDown = (e) => {
    const cell = e.target.closest('[phx-mousedown="drag_start"]');
    if (cell && cell.hasAttribute('phx-value-current_signal')) {
      isDragging = true;
      startCell = cell;

      const cycle = parseInt(cell.getAttribute('phx-value-cycle'));
      const group = cell.getAttribute('phx-value-group');
      const signal = cell.getAttribute('phx-value-current_signal');

      lastVisitedCycle = cycle;
      visitedCycles.clear();
      visitedCycles.add(cycle);

      e.preventDefault();
    }
  };

  // Track cells during drag (scoped to the hook element)
  const onMouseOver = (e) => {
    if (isDragging && startCell) {
      const cell = e.target.closest('[phx-mousedown="drag_start"]');
      if (cell && cell.getAttribute('phx-value-group') === startCell.getAttribute('phx-value-group')) {
        const signal = startCell.getAttribute('phx-value-current_signal');
        const currentCycle = parseInt(cell.getAttribute('phx-value-cycle'));
        const group = cell.getAttribute('phx-value-group');

        if (!visitedCycles.has(currentCycle)) {
          const cycleDistance = Math.abs(currentCycle - lastVisitedCycle);
          if (cycleDistance > 1) {
            hook.pushEvent('fill_gap', {
              start_cycle: lastVisitedCycle.toString(),
              end_cycle: currentCycle.toString(),
              group: group,
              signal: signal
            });
          } else {
            hook.pushEvent('update_cell_signal', {
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
  };

  // End drag operation
  const onMouseUp = (e) => {
    if (isDragging) {
      isDragging = false;
      startCell = null;
      lastVisitedCycle = null;
      visitedCycles.clear();
    }
  };

  // Cancel drag with Escape key
  const onKeyDown = (e) => {
    if (e.key === 'Escape') {
      if (isDragging) {
        isDragging = false;
        startCell = null;
        lastVisitedCycle = null;
        visitedCycles.clear();
      }
    }
  };

  // Attach listeners
  hook.el.addEventListener('mousedown', onMouseDown);
  hook.el.addEventListener('mouseover', onMouseOver);
  window.addEventListener('mouseup', onMouseUp);
  window.addEventListener('keydown', onKeyDown);

  // Cleanup when the hook is destroyed
  const cleanup = () => {
    hook.el.removeEventListener('mousedown', onMouseDown);
    hook.el.removeEventListener('mouseover', onMouseOver);
    window.removeEventListener('mouseup', onMouseUp);
    window.removeEventListener('keydown', onKeyDown);
  };

  if (typeof hook.destroyed === 'function') {
    const orig = hook.destroyed;
    hook.destroyed = function() {
      cleanup();
      orig.call(hook);
    };
  } else {
    hook.destroyed = cleanup;
  }
}
