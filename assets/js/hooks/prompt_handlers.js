export function setupPromptHandlers(hook) {
  hook.handleEvent("open_skip_prompt", ({cycle, current_duration}) => {
    const duration = prompt(`Enter skip duration (0 to remove):`, current_duration);
    if (duration !== null) {
      hook.pushEvent("set_skip", {cycle, duration});
    }
  });

  hook.handleEvent("open_wait_prompt", ({cycle, current_duration}) => {
    const duration = prompt(`Enter wait duration (0 to remove):`, current_duration);
    if (duration !== null) {
      hook.pushEvent("set_wait", {cycle, duration});
    }
  });
}
