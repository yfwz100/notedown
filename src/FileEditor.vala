namespace NoteDown {

  [GtkTemplate(ui = "/ui/file_editor.ui")]
  public class FileEditor : Adw.Bin {

    public unowned Gtk.Window window { get; set; }

    [GtkChild]
    private unowned MarkdownEditor editor;

    [GtkChild]
    private unowned Adw.ToastOverlay overlay;

    [GtkChild]
    private unowned Gtk.SearchBar search_bar;

    [GtkChild]
    private unowned Gtk.SearchEntry search_entry;

    public MarkdownEditor.SearchResult? search_result { set; get; }

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
}