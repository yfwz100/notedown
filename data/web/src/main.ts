import { MuyaEditor } from './editor/muya/muya';

import './main.scss';

self.editor = new MuyaEditor(document.getElementById('editor')!);

document.addEventListener('scroll', () => {
  const container = document.scrollingElement;
  if (!container) {
    return;
  }
  if (container.scrollTop > 0) {
    document.body.classList.add('scrolled');
  } else {
    document.body.classList.remove('scrolled');
  }
});
