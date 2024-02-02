using Gee;

public class NoteDownEditor : WebKit.WebView {

	public delegate void ReadyFunc();

	private class ReadyFuncStruct {
		public ReadyFunc call;

		public ReadyFuncStruct(owned ReadyFunc f) {
			call = (owned) f;
		}
	}

	private LinkedList<ReadyFuncStruct?> ready_funcs = new LinkedList<ReadyFuncStruct?> ();

	private bool loaded = false;

	public override void constructed() {
		base.constructed();
		this.settings = new WebKit.Settings() {
			allow_file_access_from_file_urls = true
		};
		this.set_background_color(Gdk.RGBA() { alpha = 0 });
		// this.load_uri("http://localhost:5173/");
		this.load_uri("file:///home/zhi/Work/scratch/notedown-web/dist/index.html");
		this.load_changed.connect((event) => {
			loaded = event == WebKit.LoadEvent.FINISHED;
			if (loaded) {
				foreach (var f in ready_funcs) {
					f.call();
				}
				ready_funcs.clear();
			}
		});
	}

	public void ready(owned ReadyFunc f) {
		if (loaded) {
			f();
		} else {
			ready_funcs.add(new ReadyFuncStruct((owned) f));
		}
	}

	public async void set_content(string content) throws Error {
		var args = new VariantDict();
		args.insert_value("content", new Variant.string(content));
		yield this.call_async_javascript_function("editor.setContent(content)", -1, args.end(), null, null);
	}

	public async string get_content() throws Error {
		var val = yield this.evaluate_javascript("editor.getMarkdown()", -1, null, null);

		if (!val.is_string()) {
			throw new Error(Quark.from_string("abc"), 1, "not a string");
		}
		return val.to_string();
	}
}

[GtkTemplate(ui = "/ui/main.ui")]
public class NoteDownWindow : Adw.ApplicationWindow {

	[GtkChild]
	private unowned NoteDownEditor editor { get; }

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

	public NoteDownWindow(NoteDownApp application) {
		Object(application : application);
		this.setup_actions();
	}

	private async void read_file_to_editor(File? file) {
		try {
			var data = yield file.load_bytes_async(null, null);

			var content = (string) data.get_data();
			yield editor.set_content(content);
		} catch (Error err) {
			warning("error: %s", err.message);
		}
	}

	[GtkCallback]
	private string get_title_from_file() {
		return file == null ? "Unnamed" : file.get_basename();
	}

	[GtkCallback]
	private void on_new_window() {
		this.application.lookup_action("new").activate(null);
	}

	private async void save_current_doc_async() {
		if (file != null) {
			yield save_current_doc_to_file(file);
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
		} catch (Error err) {
			warning("error: %s", err.message);
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
		} catch (Error err) {
			warning("error: %s", err.message);
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