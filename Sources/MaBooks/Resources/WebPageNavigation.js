(() => {
  if (location.protocol !== 'https:' || location.hostname !== 'weread.qq.com' ||
      !location.pathname.startsWith('/web/reader/')) return;

  const interactive = 'a,button,input,textarea,select,label,[role="button"],[role="dialog"],[role="menu"],[contenteditable]:not([contenteditable="false"])';
  let press = null;
  let pending = null;
  document.addEventListener('pointerdown', event => {
    clearTimeout(pending);
    press = event.button === 0 ? { x: event.clientX, y: event.clientY } : null;
  }, true);
  document.addEventListener('pointercancel', () => { press = null; }, true);
  document.addEventListener('click', event => {
    clearTimeout(pending);
    const start = press;
    press = null;
    if (!start || event.button !== 0 || event.detail !== 1 || event.defaultPrevented ||
        event.metaKey || event.ctrlKey || event.altKey || event.shiftKey ||
        Math.hypot(event.clientX - start.x, event.clientY - start.y) > 5 ||
        !window.getSelection()?.isCollapsed ||
        !(event.target instanceof Element) || event.target.closest(interactive)) return;

    const visible = element => {
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
    };
    const controls = Array.from(document.querySelectorAll('button,a,[role="button"]')).filter(visible);
    const label = element => (element.getAttribute('aria-label') || element.textContent || '').replace(/\s/g, '').replace(/[‹›〈〉《》<>←→]/g, '');
    const previous = controls.find(element => label(element) === '上一页');
    const next = controls.find(element => label(element) === '下一页');
    if (!previous || !next) return;

    // Find the visible reading card enclosing both official page controls, not the footer strip.
    let card = previous.parentElement;
    while (card && (!card.contains(next) || card.getBoundingClientRect().height < 240)) card = card.parentElement;
    if (!card || card === document.body || card === document.documentElement) return;
    const rect = card.getBoundingClientRect();
    if (rect.width < 320 || event.clientY < rect.top + 48 || event.clientY > rect.bottom - 48 ||
        event.clientX < rect.left || event.clientX > rect.right) return;
    const fraction = (event.clientX - rect.left) / rect.width;
    const button = fraction <= 0.20 ? previous : fraction >= 0.80 ? next : null;
    if (!button || button.disabled || button.getAttribute('aria-disabled') === 'true' ||
        button.classList.contains('disabled') || button.classList.contains('is-disabled')) return;
    event.preventDefault();
    event.stopPropagation();
    const pageURL = location.href;
    pending = setTimeout(() => {
      if (location.href === pageURL && button.isConnected && visible(button) &&
          !button.disabled && button.getAttribute('aria-disabled') !== 'true' &&
          !button.classList.contains('disabled') && !button.classList.contains('is-disabled') &&
          window.getSelection()?.isCollapsed) button.click();
    }, __DOUBLE_CLICK_DELAY__);
  }, true);
})();
