export function setupInputHandlers(hook) {
  // Number input handler used to push immediate updates when mounted
  const onInput = (e) => {
    const field = hook.el.dataset.field;
    const value = hook.el.value;
    // Send update to server
    if (field === "length") {
      hook.pushEvent("update_program_length_immediate", { value });
    } else if (field === "offset") {
      hook.pushEvent("update_program_offset_immediate", { value });
    }
  };

  hook.el.addEventListener('input', onInput);

  // Cleanup
  const cleanup = () => hook.el.removeEventListener('input', onInput);
  if (typeof hook.destroyed === 'function') {
    const origDestroyed = hook.destroyed;
    hook.destroyed = function() { cleanup(); origDestroyed.call(hook); };
  } else {
    hook.destroyed = cleanup;
  }
}
