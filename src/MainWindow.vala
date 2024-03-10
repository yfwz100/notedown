namespace NoteDown {

  [GtkTemplate(ui = "/ui/main_window.ui")]
  public class MainWindow : Adw.ApplicationWindow {
  
    [GtkChild]
    private unowned FileEditor _file_editor;
  
    public unowned FileEditor file_editor { get { return _file_editor; } }
  
    public MainWindow(App application) {
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
}