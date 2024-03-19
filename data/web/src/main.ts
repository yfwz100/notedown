import { MuyaEditor } from './editor/muya/muya';

import './main.scss';
import { native } from './native/proxy';

self.editor = new MuyaEditor(document.getElementById('editor')!);

const scrolled = { value: false };
document.addEventListener('scroll', () => {
  let oldScrolled = scrolled.value;
  const container = document.scrollingElement;
  if (!container) {
    return;
  }
  if (container.scrollTop > 0) {
    scrolled.value = true;
  } else {
    scrolled.value = false;
  }
  if (oldScrolled !== scrolled.value) {
    native.syncScrolled(scrolled.value);
  }
});
