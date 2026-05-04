import gi
try:
    gi.require_version('Nautilus', '4.1')
except ValueError:
    pass # Already loaded by another extension
from gi.repository import Nautilus, GObject
import subprocess

class CopyPathExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()

    def get_file_items(self, files):
        if not files:
            return []

        item = Nautilus.MenuItem(
            name='CopyPathExtension::CopyPath',
            label='Copy File Location',
            tip='Copy the full path of the selected file(s)'
        )
        item.connect('activate', self.menu_activate_cb, files)
        return [item]

    def get_background_items(self, folder):
        item = Nautilus.MenuItem(
            name='CopyPathExtension::CopyFolderPath',
            label='Copy Folder Location',
            tip='Copy the full path of the current folder'
        )
        item.connect('activate', self.menu_activate_cb, [folder])
        return [item]

    def menu_activate_cb(self, menu, files):
        paths = []
        for file in files:
            # Handle get_location() depending on Nautilus API version
            location = file.get_location()
            if location:
                path = location.get_path()
                if path:
                    paths.append(path)

        if paths:
            text = "\n".join(paths)
            try:
                subprocess.run(['wl-copy'], input=text.encode('utf-8'))
            except Exception as e:
                print(f"Failed to copy to clipboard: {e}")
