export function setupInputHandlers(hook) {
  console.log("NumberInputHandler mounted for", hook.el.dataset.field);
  
  // Listen for any changes including keyboard, mouse clicks, arrow buttons, etc.
  hook.el.addEventListener('input', (e) => {
    const field = hook.el.dataset.field;
    const value = hook.el.value;
    
    console.log(`Input changed: ${field} = ${value}`);
    
    // Send update to server
    if (field === "length") {
      hook.pushEvent("update_program_length_immediate", { value });
    } else if (field === "offset") {
      hook.pushEvent("update_program_offset_immediate", { value });
    }
  });
}
