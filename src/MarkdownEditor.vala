namespace NoteDown {

  public class MarkdownEditor : Adw.Bin {
  
    public class SearchResult : Object {
      private unowned MarkdownEditor editor;
  
      public SearchResult(MarkdownEditor editor) {
        this.editor = editor;
      }
  
      public async void highlight_next() {
        yield this.highlight("next");
      }
  
      public async void highlight_prev() {
        yield this.highlight("prev");
      }
  
      protected async void highlight(string dir) {
        try {
          var args = new VariantDict();
          args.insert_value("dir", new Variant.string(dir));
          yield this.editor.web_view.call_async_javascript_function("editor.find(dir)", -1, args.end(), null, null);
        } catch (Error err) {
          warning("highlight: %s", err.message);
        }
      }
    }
  
    public delegate void ReadyFunc();
  
    private class ReadyFuncItem {
      public ReadyFunc call;
  
      public ReadyFuncItem(owned ReadyFunc ready) {
        call = (owned) ready;
      }
    }
  
    private Gee.LinkedList<ReadyFuncItem?> ready_funcs = new Gee.LinkedList<ReadyFuncItem?> ();
  
    private unowned WebKit.WebView web_view;
  
    private bool loaded = false;
  
    public signal void state_updated();
  
    public string base_path { set; get; }
  
    public bool can_redo { private set; get; }
  
    public bool can_undo { private set; get; }
  
    public string synced_content { private set; get; }

    public bool scrolled { private set; get; }
  
    private abstract class JSFunc {
      protected unowned MarkdownEditor editor;
  
      protected JSFunc(MarkdownEditor editor) {
        this.editor = editor;
      }
  
      public abstract async JSC.Value ? call(JSC.Context ctx, JSC.Value args) throws Error;
    }
  
    private Gee.Map<string, JSFunc> js_func_map = new Gee.HashMap<string, JSFunc> ();
  
    private class JSSyncStateFunc : JSFunc {
  
      public JSSyncStateFunc(MarkdownEditor editor) {
        base(editor);
      }
  
      public async override JSC.Value ? call(JSC.Context ctx, JSC.Value args) {
        var state = args.object_get_property_at_index(0);
        if (!state.is_object()) {
          return null;
        }
        editor.synced_content = state.object_get_property("content").to_string();
        editor.can_undo = state.object_get_property("canUndo").to_boolean();
        editor.can_redo = state.object_get_property("canRedo").to_boolean();
        editor.state_updated();
        return null;
      }
    }
  
    private class JSSelectFileFunc : JSFunc {
  
      public JSSelectFileFunc(MarkdownEditor editor) {
        base(editor);
      }
  
      public async override JSC.Value ? call(JSC.Context ctx, JSC.Value args) throws Error {
        var file_dialog = new Gtk.FileDialog();
        var ret = yield file_dialog.open(null, null);
  
        if (ret == null) {
          return null;
        }
        return new JSC.Value.string(ctx, ret.get_path());
      }
    }

    private class JSSyncScrolledFunc : JSFunc {
      public JSSyncScrolledFunc(MarkdownEditor editor) {
        base(editor);
      }
  
      public async override JSC.Value ? call(JSC.Context ctx, JSC.Value args) throws Error {
        editor.scrolled = args.object_get_property_at_index(0).to_boolean();
        return null;
      }
    }
  
    public override void constructed() {
      base.constructed();
  
      var web_view = new WebKit.WebView() {
        settings = new WebKit.Settings() {
          allow_file_access_from_file_urls = true,
          allow_universal_access_from_file_urls = true,
          enable_javascript = true,
          enable_javascript_markup = true,
          javascript_can_access_clipboard = true,
          enable_developer_extras = true,
          disable_web_security = true
        },
      };
      web_view.set_background_color(Gdk.RGBA() { alpha = 0 });
  
      js_func_map.set("syncState", new JSSyncStateFunc(this));
      js_func_map.set("selectFile", new JSSelectFileFunc(this));
      js_func_map.set("syncScrolled", new JSSyncScrolledFunc(this));
  
      var ucm = web_view.user_content_manager;
      ucm.script_message_with_reply_received.connect(hanlde_script_messages);
      string world_name = null;
      ucm.register_script_message_handler_with_reply("editor", world_name);
  
      web_view.web_context.register_uri_scheme("builtin", (req) => {
        try {
          var path = req.get_path();
          if (path[0] == '/') {
            path = path[1 : ];
          }
          var res_file = File.new_for_uri("resource:///web/%s".printf(path));
          var data = res_file.load_bytes(null, null);
          var memory = new MemoryInputStream.from_bytes(data);
          req.finish(memory, data.get_size(), null);
        } catch (Error err) {
          req.finish_error(err);
          warning("error handling custom uri: %s", err.message);
        }
      });
  
      // web_view.web_context.get_security_manager().register_uri_scheme_as_cors_enabled("builtin");
      web_view.load_uri("builtin:///editor/index.html");
      web_view.load_changed.connect((event) => {
        loaded = event == WebKit.LoadEvent.FINISHED;
        if (loaded) {
          foreach (var f in ready_funcs) {
            f.call();
          }
          ready_funcs.clear();
        }
      });
  
      this.child = web_view;
  
      this.web_view = web_view;
    }
  
    private bool hanlde_script_messages(JSC.Value msg_value, WebKit.ScriptMessageReply reply) {
      if (!msg_value.is_object()) {
        return false;
      }
      var func_name = msg_value.object_get_property("func").to_string();
      var args = msg_value.object_get_property("args");
      if (!args.is_array()) {
        return false;
      }
      var func = js_func_map.get(func_name);
      if (func == null) {
        error("call undefined function %s", func_name);
      }
      reply.ref();
      func.call.begin(msg_value.context, args, (obj, res) => {
        try {
          var val = func.call.end(res);
          if (val != null) {
            reply.return_value(val);
          }
        } catch (Error err) {
          reply.return_error_message(err.message);
        }
      });
      return true;
    }
  
    public void ready(owned ReadyFunc ready) {
      if (loaded) {
        ready();
      } else {
        ready_funcs.add(new ReadyFuncItem((owned) ready));
      }
    }
  
    public async SearchResult ? search(string keyword) throws Error {
      var args = new VariantDict();
      args.insert_value("keyword", new Variant.string(keyword));
      yield this.web_view.call_async_javascript_function("editor.search(keyword)", -1, args.end(), null, null);
  
      if (keyword == "") {
        return null;
      }
      return new SearchResult(this);
    }
  
    public async void set_content(string content, string path = "") throws Error {
      this.base_path = path;
  
      var args = new VariantDict();
      args.insert_value("content", new Variant.string(content));
      args.insert_value("basePath", new Variant.string(path));
      yield this.web_view.call_async_javascript_function("editor.setContent(content, basePath)",
        -1, args.end(),
        null,
        null);
    }
  
    public async string get_content() throws Error {
      var val = yield this.web_view.evaluate_javascript("editor.getMarkdown()", -1, null, null);
  
      if (!val.is_string()) {
        throw new Error(Quark.from_string("abc"), 1, "not a string");
      }
      return val.to_string();
    }
  
    public async void undo() throws Error {
      yield this.web_view.evaluate_javascript("editor.undo()", -1, null, null);
    }
  
    public async void redo() throws Error {
      yield this.web_view.evaluate_javascript("editor.redo()", -1, null, null);
    }
  }
}