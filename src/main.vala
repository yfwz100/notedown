using Gee;

[GtkTemplate(ui = "/ui/file_prop_form.ui")]
public class FilePropForm : Adw.Bin {

  public File? file {
    set {
      read_attrs_from_file.begin(value);
    }
  }

  public string file_name { get; set; }
  public string file_path { get; set; }
  public string file_size { get; set; }

  private async void read_attrs_from_file(File? file) throws Error {
    if (file == null) {
      return;
    }

    file_name = file.get_basename();
    file_path = file.get_parent().get_path();

    var data = yield file.load_bytes_async(null, null);

    file_size = "%d kB".printf(data.length / 1024);
  }

  [GtkCallback]
  public void copy_file_name() {
    copy_text(file_name);
  }

  [GtkCallback]
  public void copy_file_path() {
    copy_text(file_path);
  }

  protected void copy_text(string text) {
    get_clipboard().set_text(text);
  }
}

public class NoteDownEditor : Adw.Bin {

  public class SearchResult : Object {
    private unowned NoteDownEditor editor;

    public SearchResult(NoteDownEditor editor) {
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

  private LinkedList<ReadyFuncItem?> ready_funcs = new LinkedList<ReadyFuncItem?> ();

  private unowned WebKit.WebView web_view;

  private bool loaded = false;

  public signal void state_updated();

  public string base_path { set; get; }

  public bool can_redo { private set; get; }

  public bool can_undo { private set; get; }

  public string synced_content { private set; get; }

  private abstract class JSFunc {
    protected unowned NoteDownEditor editor;

    protected JSFunc(NoteDownEditor editor) {
      this.editor = editor;
    }

    public abstract async JSC.Value ? call(JSC.Context ctx, JSC.Value args) throws Error;
  }

  private Map<string, JSFunc> js_func_map = new HashMap<string, JSFunc> ();

  private class JSSyncStateFunc : JSFunc {

    public JSSyncStateFunc(NoteDownEditor editor) {
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

    public JSSelectFileFunc(NoteDownEditor editor) {
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

[GtkTemplate(ui = "/ui/file_editor.ui")]
public class NoteDownFileEditor : Adw.Bin {

  public unowned Gtk.Window window { get; set; }

  [GtkChild]
  private unowned NoteDownEditor editor;

  [GtkChild]
  private unowned Adw.ToastOverlay overlay;

  [GtkChild]
  private unowned Gtk.SearchBar search_bar;

  [GtkChild]
  private unowned Gtk.SearchEntry search_entry;

  public NoteDownEditor.SearchResult? search_result { set; get; }

  private File? _file;

  public File? file {
    set {
      _file = value;
      if (_file != null) {
        editor.ready(() => {
          read_file_to_editor.begin(_file);
        });
      }
    }
    get {
      return _file;
    }
  }

  private string saved_content;

  public override void constructed() {
    this.setup_ui();
  }

  private void setup_ui() {
    search_bar.connect_entry(search_entry);
    search_bar.notify["search-mode-enabled"].connect_after(() => {
      if (!search_bar.search_mode_enabled) {
        this.editor.search.begin("");
        this.search_result = null;
      }
    });
  }

  public void show_toast(string msg) {
    overlay.add_toast(new Adw.Toast(msg));
  }

  private bool is_modified() {
    if (this.editor == null) {
      return false;
    }
    return this.editor.synced_content != this.saved_content;
  }

  [GtkCallback]
  private void on_new_window() {
    this.window.application.lookup_action("new").activate(null);
  }

  [GtkCallback]
  private void on_undo() {
    this.editor.undo.begin();
  }

  [GtkCallback]
  private void on_redo() {
    this.editor.redo.begin();
  }

  [GtkCallback]
  private bool has_search_result() {
    return search_result != null;
  }

  private async void read_file_to_editor(File? file) {
    try {
      var data = yield file.load_bytes_async(null, null);

      var content = (string) data.get_data();
      yield editor.set_content(content, file.get_parent().get_path());

      saved_content = content;
    } catch (Error err) {
      warning("error: %s", err.message);
    }
  }

  private async void save_current_doc_async() {
    if (file != null) {
      yield save_current_doc_to_file(file);

      this.file = file;
    } else {
      file = yield save_as_doc_async();
    }
  }

  public void save_current_doc() {
    save_current_doc_async.begin();
  }

  private async File ? save_as_doc_async() {
    File? file = null;
    try {
      file = yield(new Gtk.FileDialog()).save(window, null);
      return_if_fail(file != null);
      yield save_current_doc_to_file(file);

      this._file = file;
    } catch (Error err) {
      show_toast(err.message);
    }
    return file;
  }

  private async void save_current_doc_to_file(File file) {
    try {
      var text = yield editor.get_content();

      var stream = file.query_exists() ?
        yield file.open_readwrite_async() :
        yield file.create_readwrite_async(FileCreateFlags.NONE);

      warn_if_fail(yield stream.output_stream.write_all_async(text.data, Priority.DEFAULT, null, null));
      warn_if_fail(yield stream.close_async());

      show_toast("Save successfully!");

      saved_content = text;
    } catch (Error err) {
      show_toast(err.message);
    }
  }

  public void save_as_doc() {
    save_as_doc_async.begin();
  }

  [GtkCallback]
  private string get_title_from_file() {
    return "%s %s".printf(file == null ? "Unnamed" : file.get_basename(), is_modified() ? "*" : "");
  }

  public void toggle_search() {
    search_bar.search_mode_enabled = !search_bar.search_mode_enabled;
  }

  [GtkCallback]
  private void on_search() {
    this.editor.search.begin(search_entry.text, (obj, res) => {
      try {
        this.search_result = this.editor.search.end(res);
      } catch (Error err) {
        warning("search error: %s", err.message);
      }
    });
  }

  [GtkCallback]
  private void find_next() {
    if (this.search_result == null) {
      return;
    }
    this.search_result.highlight_next.begin();
  }

  [GtkCallback]
  private void find_prev() {
    if (this.search_result == null) {
      return;
    }
    this.search_result.highlight_prev.begin();
  }
}

[GtkTemplate(ui = "/ui/main_window.ui")]
public class NoteDownWindow : Adw.ApplicationWindow {

  [GtkChild]
  private unowned NoteDownFileEditor _file_editor;

  public unowned NoteDownFileEditor file_editor { get { return _file_editor; } }

  public NoteDownWindow(NoteDownApp application) {
    Object(application : application);
    this.setup_ui();
    this.setup_actions();
  }

  private void setup_ui() {
    this.file_editor.window = this;
  }

  private void setup_actions() {
    var win_actions = new SimpleActionGroup();
    this.insert_action_group("win", win_actions);

    var find_replace_action = new SimpleAction("find-and-replace", null);
    find_replace_action.activate.connect(() => {
      file_editor.toggle_search();
    });
    win_actions.add_action(find_replace_action);
    this.application.set_accels_for_action("win.find-and-replace", { "<Control>f" });

    var save_action = new SimpleAction("save", null);
    save_action.activate.connect(() => {
      file_editor.save_current_doc();
    });
    win_actions.add_action(save_action);
    this.application.set_accels_for_action("win.save", { "<Control>s" });

    var save_as_action = new SimpleAction("save-as", null);
    save_as_action.activate.connect(() => {
      file_editor.save_as_doc();
    });
    win_actions.add_action(save_as_action);
    this.application.set_accels_for_action("win.save-as", { "<Control><Alt>s" });
  }
}

public class NoteDownApp : Adw.Application {

  public NoteDownApp() {
    Object(application_id : "io.gitee.zhi.notedown.App", flags : ApplicationFlags.FLAGS_NONE);
    this.setup_actions();
  }

  public void show_new_window() {
    new NoteDownWindow(this).present();
  }

  private async void open_window_by_file_async() {
    try {
      var file = yield(new Gtk.FileDialog()).open(get_active_window(), null);
      return_if_fail(file != null);

      var current_window = this.get_active_window() as NoteDownWindow;
      if (current_window != null && current_window.file_editor.file == null) {
        current_window.file_editor.file = file;
        return;
      }

      var editorWindow = new NoteDownWindow(this);
      editorWindow.file_editor.file = file;
      editorWindow.present();
    } catch (Error err) {
      warning("error: %s", err.message);
    }
  }

  public void open_window_by_file() {
    open_window_by_file_async.begin();
  }

  public void show_pref_window() {
    // TODO
  }

  public void show_about_window() {
    Adw.show_about_window(this.get_active_window(),
                          "application-icon", "notedown",
                          "application-name", "NoteDown",
                          "developer-name", "Wang",
                          "comments", "A simple markdown editor",
                          "website", "https://zhi.gitee.io/notedown/",
                          "issue-url", "https://gitee.com/zhi/notedown/issues",
                          "support-url", "https://gitee.com/zhi/notedown/issues",
                          "version", "1.0.0",
                          "copyright", "© 2024 Wang",
                          "license-type", Gtk.License.MIT_X11
    );
  }

  private void setup_actions() {
    var new_action = new SimpleAction("new", null);
    new_action.activate.connect(show_new_window);
    this.add_action(new_action);
    this.set_accels_for_action("app.new", { "<Control>n" });

    var open_action = new SimpleAction("open", null);
    open_action.activate.connect(open_window_by_file);
    this.add_action(open_action);
    this.set_accels_for_action("app.open", { "<Control>o" });

    var about_action = new SimpleAction("about", null);
    about_action.activate.connect(show_about_window);
    this.add_action(about_action);

    var pref_action = new SimpleAction("preference", null);
    pref_action.activate.connect(show_pref_window);
    this.add_action(pref_action);
    this.set_accels_for_action("app.preference", { "<Control>comma" });
  }

  public override void activate() {
    show_new_window();
  }
}

int main(string[] args) {
  return new NoteDownApp().run(args);
}