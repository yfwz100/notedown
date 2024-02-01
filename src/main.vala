public class NoteDownEditor : WebKit.WebView {

	public override void constructed() {
		base.constructed();
		this.settings = new WebKit.Settings() {
			allow_file_access_from_file_urls = true
		};
		this.set_background_color(Gdk.RGBA() { alpha = 0 });
		this.load_uri("http://localhost:5173/");
		// this.load_uri("file:///home/zhi/Work/scratch/notedown-web/dist/index.html");
	}

	public async string get_markdown() throws Error {
		var val = yield this.evaluate_javascript("editor.getMarkdown()", -1, null, null, null);
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

	public NoteDownWindow(NoteDownApp application) {
		Object(application: application);
		this.setup_actions();
	}

	[GtkCallback]
	private void on_new_window() {
		this.application.lookup_action("new").activate(null);
	}

	public void save_current_doc() {
		
	}

	public void save_as_doc() {
		// TODO
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
		Object(application_id: "io.gitee.zhi.notedown.App", flags: ApplicationFlags.FLAGS_NONE);
		this.setup_actions();
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

	public void show_pref_window() {
		// TODO
	}

	public void show_new_window() {
		new NoteDownWindow(this).present();
	}

	private void setup_actions() {
		var new_action = new SimpleAction("new", null);
		new_action.activate.connect(show_new_window);
		this.add_action(new_action);
		this.set_accels_for_action("app.new", { "<Control>n" });

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