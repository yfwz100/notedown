namespace NoteDown {

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
}