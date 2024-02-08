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
import './main.scss';

interface SearchOption {
  isCaseSensitive?: boolean;
  isWholeWord?: boolean;
  isRegexp?: boolean;
  selectHighlight?: boolean;
  highlightIndex?: number;
}

interface ReplaceOption {
  isSingle: boolean;
  isRegexp: boolean;
}

interface Editor {
  setContent(content: string): void;
  search(value: string, opt?: SearchOption): void;
  find(action: 'previous' | 'next'): void;
  replace(replaceValue: string, opt?: ReplaceOption): void;
  getMarkdown(): string;
}

interface WebKitMessageHandler {
  postMessage: typeof postMessage;
}

interface WebKit {
  messageHandlers: {
    [key: string]: WebKitMessageHandler;
  };
}

// extends the global window to add editor.
declare global {
  interface Window {
    editor: Editor;
    webkit: WebKit;
  }
}

Muya.use(EmojiSelector);
Muya.use(InlineFormatToolbar);
// Muya.use(ImageEditTool, {
//   imagePathPicker,
//   imageAction,
// });
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

const editor = new Muya(document.getElementById('editor')!, {
  hideQuickInsertHint: true,
  hideLinkPopup: true,
});
editor.init();

self.editor = new (class implements Editor {
  setContent(content: string): void {
    editor.setContent(content);
  }
  search(value: string, opt?: SearchOption | undefined): void {
    editor.search(value, opt!);
  }
  find(action: 'previous' | 'next'): void {
    editor.find(action);
    setTimeout(() => {
      document.querySelector('.mu-highlight')?.scrollIntoView();
    });
  }
  replace(replaceValue: string, opt?: ReplaceOption | undefined): void {
    throw new Error('Method not implemented.');
  }
  getMarkdown(): string {
    return editor.getMarkdown();
  }
})();

// setInterval(() => {
//   alert('hello'+window.webkit);
//   window.webkit.messageHandlers.editor.postMessage("hello");
// }, 1000);
