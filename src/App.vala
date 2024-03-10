namespace NoteDown {

  public class App : Adw.Application {
  
    public App() {
      Object(application_id : "io.gitee.zhi.notedown.App", flags : ApplicationFlags.FLAGS_NONE);
      this.setup_actions();
    }
  
    public void show_new_window() {
      new MainWindow(this).present();
    }
  
    private async void open_window_by_file_async() {
      try {
        var file = yield(new Gtk.FileDialog()).open(get_active_window(), null);
        return_if_fail(file != null);
  
        var current_window = this.get_active_window() as MainWindow;
        if (current_window != null && current_window.file_editor.file == null) {
          current_window.file_editor.file = file;
          return;
        }
  
        var editorWindow = new MainWindow(this);
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
}

int main(string[] args) {
  return new NoteDown.App().run(args);
}