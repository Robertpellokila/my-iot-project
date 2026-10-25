import { computed, nextTick, onBeforeUnmount, watch } from 'vue';

// Existing battle pickers share one keyboard/focus lifecycle.
export function useActionDialogFocus(dialogs, busy) {
  let previousFocus;
  let removeListener;
  const active = computed(() => dialogs.find(dialog => dialog.open.value));
  watch(active, async (dialog, previous, cleanup) => {
    removeListener?.();
    removeListener = null;
    if (!dialog) {
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
      previousFocus = null;
      return;
    }
    if (!previous) previousFocus = document.activeElement;
    let cancelled = false;
    cleanup(() => { cancelled = true; });
    await nextTick();
    if (cancelled) return;
    const element = document.querySelector(dialog.selector);
    if (!element) return;
    element.focus({ preventScroll: true });
    const keydown = event => {
      if (event.key === 'Escape') {
        event.preventDefault();
        if (!busy.value) dialog.close();
      }
      if (event.key !== 'Tab') return;
      const buttons = [...element.querySelectorAll('button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href],[tabindex="0"]')]
        .filter(node => node.getClientRects().length);
      const first = buttons[0], last = buttons.at(-1);
      if (!first) { event.preventDefault(); element.focus(); return; }
      if (event.shiftKey && (document.activeElement === first || document.activeElement === element)) { event.preventDefault(); last.focus(); }
      else if (!event.shiftKey && (document.activeElement === last || !element.contains(document.activeElement))) { event.preventDefault(); first.focus(); }
    };
    document.addEventListener('keydown', keydown);
    removeListener = () => document.removeEventListener('keydown', keydown);
  });
  onBeforeUnmount(() => removeListener?.());
}
