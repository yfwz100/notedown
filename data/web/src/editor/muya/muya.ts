import Muya from '@marktext/muya';
import {
  CodeBlockLanguageSelector,
  EmojiSelector,
  ImageEditTool,
  ImageResizeBar,
  ImageToolBar,
  InlineFormatToolbar,
  ParagraphFrontButton,
  ParagraphFrontMenu,
  ParagraphQuickInsertMenu,
  PreviewToolBar,
  TableColumnToolbar,
  TableDragBar,
  TableRowColumMenu,
} from '@marktext/muya/dist/ui';
import '@marktext/muya/dist/assets/style.css';
import { Editor, ReplaceOption, SearchOption } from '../api';

function createNativeProxy<T extends Record<string, unknown>>(name: string) {
  return new Proxy({} as T, {
    get(_, key) {
      return function (...args: unknown[]) {
        return window.webkit?.messageHandlers[name].postMessage({
          func: key,
          args,
        });
      };
    },
  });
}

const native = createNativeProxy<{
  selectFile(): Promise<string>;
  syncState(state: { content: string; canUndo: boolean; canRedo: boolean }): Promise<void>;
}>('editor');

Muya.use(EmojiSelector);
Muya.use(InlineFormatToolbar);
const imagePathPicker = async () => {
  return native.selectFile();
};
Muya.use(ImageEditTool, {
  imagePathPicker,
});
Muya.use(ImageToolBar);
Muya.use(ImageResizeBar);
Muya.use(CodeBlockLanguageSelector);

Muya.use(ParagraphFrontButton);
Muya.use(ParagraphFrontMenu);
Muya.use(TableColumnToolbar);
Muya.use(ParagraphQuickInsertMenu);
Muya.use(TableDragBar);
Muya.use(TableRowColumMenu);
Muya.use(PreviewToolBar);

export class MuyaEditor implements Editor {
  private editor: Muya;
  private basePath?: string;

  constructor(el: HTMLElement) {
    const editor = new Muya(el);
    editor.init();

    const parent = this;
    const { image } = editor.editor.inlineRenderer.renderer;
    editor.editor.inlineRenderer.renderer.image = function (params) {
      if (params.token.attrs.src.startsWith('.')) {
        params.token.attrs.src = parent.basePath + '/' + params.token.attrs.src;
      }
      return image.call(this, params);
    };

    editor.on('json-change', () => {
      const h = editor.editor.history as unknown as { stack: { redo: unknown[]; undo: unknown[] } };
      native.syncState({
        content: editor.getMarkdown(),
        canUndo: h.stack.undo.length > 0,
        canRedo: h.stack.redo.length > 0,
      });
    });
    this.editor = editor;
  }

  setContent(content: string, basePath?: string): void {
    this.basePath = basePath;
    this.editor.setContent(content);
  }

  search(value: string, opt?: SearchOption): void {
    this.editor.search(value, opt!);
  }

  find(action: 'previous' | 'next'): void {
    this.editor.find(action);
    setTimeout(() => {
      document.querySelector('.mu-highlight')?.scrollIntoView();
    });
  }

  replace(replaceValue: string, opt?: ReplaceOption): void {
    throw new Error('Method not implemented.');
  }

  undo() {
    this.editor.undo();
  }

  redo() {
    this.editor.redo();
  }

  getMarkdown(): string {
    return this.editor.getMarkdown();
  }
}
