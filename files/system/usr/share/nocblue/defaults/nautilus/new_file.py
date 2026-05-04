import gi
try:
    gi.require_version('Nautilus', '4.1')
except ValueError:
    pass
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Nautilus, GObject, Gtk, Adw, Gio
import os


class NewFileExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()

    def get_background_items(self, folder):
        item = Nautilus.MenuItem(
            name='NewFileExtension::NewFile',
            label='New File',
            tip='Create a new empty file'
        )
        item.connect('activate', self._on_activate, folder)
        return [item]

    def _on_activate(self, menu, folder):
        location = folder.get_location()
        if not location:
            return
        folder_path = location.get_path()
        if not folder_path:
            return

        app = Gtk.Application.get_default()
        window = app.get_active_window() if app else None

        dialog = Adw.AlertDialog(
            heading='New File',
            body='Enter a name for the new file:',
            close_response='cancel',
        )
        dialog.add_response('cancel', 'Cancel')
        dialog.add_response('create', 'Create')
        dialog.set_response_appearance('create', Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response('create')

        entry = Gtk.Entry()
        entry.set_activates_default(True)
        entry.set_can_focus(True)
        dialog.set_extra_child(entry)

        def on_map(_widget):
            entry.grab_focus()

        entry.connect('map', on_map)
        dialog.choose(window, None, self._on_response, entry, folder_path)

    def _on_response(self, dialog, result, entry, folder_path):
        response = dialog.choose_finish(result)
        if response != 'create':
            return
        name = entry.get_text().strip()
        if not name:
            return
        filepath = os.path.join(folder_path, name)
        if os.path.exists(filepath):
            return
        open(filepath, 'w').close()
