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

	public signal void content_updated(string content);

	public override void constructed() {
		base.constructed();

		var web_view = new WebKit.WebView() {
			settings = new WebKit.Settings() {
				allow_file_access_from_file_urls = true,
				enable_javascript = true,
				enable_javascript_markup = true,
				javascript_can_access_clipboard = true,
				enable_developer_extras = true
			},
		};
		web_view.set_background_color(Gdk.RGBA() { alpha = 0 });

		var ucm = web_view.user_content_manager;
		ucm.script_message_received.connect(hanlde_script_messages);
		string world_name = null;
		ucm.register_script_message_handler("editor", world_name);

		web_view.load_uri("file:///home/zhi/Work/scratch/notedown-web/dist/index.html");
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

	private void hanlde_script_messages(JSC.Value msg_value) {
		if (!msg_value.is_object()) {
			return_if_reached();
		}
		var msg_type = msg_value.object_get_property("type").to_string();
		switch (msg_type) {
		case "content-change":
			this.content_updated(msg_value.object_get_property("content").to_string());
			break;
		default:
			stdout.printf("unknown msg type: %s", msg_type);
			break;
		}
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

	public async void set_content(string content) throws Error {
		var args = new VariantDict();
		args.insert_value("content", new Variant.string(content));
		yield this.web_view.call_async_javascript_function("editor.setContent(content)", -1, args.end(), null, null);
	}

	public async string get_content() throws Error {
		var val = yield this.web_view.evaluate_javascript("editor.getMarkdown()", -1, null, null);

		if (!val.is_string()) {
			throw new Error(Quark.from_string("abc"), 1, "not a string");
		}
		return val.to_string();
	}
}

[GtkTemplate(ui = "/ui/main_window.ui")]
public class NoteDownWindow : Adw.ApplicationWindow {

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

	public bool modified { private set; get; }

	public NoteDownWindow(NoteDownApp application) {
		Object(application : application);
		this.setup_actions();
		this.setup_ui();
	}

	private void setup_ui() {
		search_bar.connect_entry(search_entry);
		search_bar.set_key_capture_widget(this);
		search_bar.notify["search-mode-enabled"].connect_after(() => {
			if (!search_bar.search_mode_enabled) {
				this.editor.search.begin("");
				this.search_result = null;
			}
		});

		editor.content_updated.connect_after((content) => {
			modified = content != saved_content;
		});
	}

	[GtkCallback]
	private bool has_search_result() {
		return search_result != null;
	}

	private async void read_file_to_editor(File? file) {
		try {
			var data = yield file.load_bytes_async(null, null);

			var content = (string) data.get_data();
			yield editor.set_content(content);

			saved_content = content;
			modified = false;
		} catch (Error err) {
			warning("error: %s", err.message);
		}
	}

	[GtkCallback]
	public bool is_file_valid() {
		return file != null;
	}

	[GtkCallback]
	private string get_title_from_file() {
		return "%s %s".printf(file == null ? "Unnamed" : file.get_basename(), modified ? "*" : "");
	}

	[GtkCallback]
	private void on_new_window() {
		this.application.lookup_action("new").activate(null);
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

	public void show_toast(string msg) {
		overlay.add_toast(new Adw.Toast(msg));
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
			file = yield(new Gtk.FileDialog()).save(this, null);
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

	private void setup_actions() {
		var win_actions = new SimpleActionGroup();
		this.insert_action_group("win", win_actions);

		var find_replace_action = new SimpleAction("find-and-replace", null);
		find_replace_action.activate.connect(save_current_doc);
		win_actions.add_action(find_replace_action);
		this.application.set_accels_for_action("win.find-and-replace", { "<Control>f" });

		var save_action = new SimpleAction("save", null);
		save_action.activate.connect(save_current_doc);
		win_actions.add_action(save_action);
		this.application.set_accels_for_action("win.save", { "<Control>s" });

		var save_as_action = new SimpleAction("save-as", null);
		save_as_action.activate.connect(save_as_doc);
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
			if (current_window != null && current_window.file == null) {
				current_window.file = file;
				return;
			}

			var editorWindow = new NoteDownWindow(this);
			editorWindow.file = file;
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