import { Editor } from './editor/api';

// extends the global window to add editor.
declare global {
  interface WebKitMessageHandler {
    postMessage: typeof postMessage;
  }

  interface WebKit {
    messageHandlers: {
      [key: string]: WebKitMessageHandler;
    };
  }

  interface Window {
    editor: Editor;
    webkit?: WebKit;
  }
}

export {}