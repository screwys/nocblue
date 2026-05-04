import gi
try:
    gi.require_version('Nautilus', '4.1')
except ValueError:
    pass
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Nautilus, GObject, Gtk, Adw, GLib
import os, subprocess


class FolderIconExtension(GObject.GObject, Nautilus.MenuProvider):
    def __init__(self):
        super().__init__()

    def get_file_items(self, files):
        if len(files) != 1 or not files[0].is_directory():
            return []
        item = Nautilus.MenuItem(
            name='FolderIconExtension::ChangeIcon',
            label='Change Folder Icon',
            tip='Pick an icon for this folder'
        )
        item.connect('activate', self._on_activate, files[0])
        return [item]

    def _scan_icons(self, theme_name):
        """Scan all icons, deduplicated by name, preferring 48px."""
        icons = {}  # name -> path
        scan_dirs = [
            os.path.join('/usr/share/icons', theme_name),
            os.path.join(os.path.expanduser('~/.local/share/icons'), theme_name),
            os.path.join(os.path.expanduser('~/.icons'), theme_name),
            '/usr/share/pixmaps',
        ]
        for scan_dir in scan_dirs:
            if not os.path.isdir(scan_dir):
                continue
            for root, dirs, files in os.walk(scan_dir):
                is_48 = '/48' in root
                for f in files:
                    if not f.endswith(('.svg', '.png', '.ico')):
                        continue
                    name = os.path.splitext(f)[0]
                    if name not in icons or is_48:
                        icons[name] = os.path.join(root, f)
        return icons

    def _on_activate(self, menu, file):
        folder_path = file.get_location().get_path()
        if not folder_path:
            return

        app = Gtk.Application.get_default()
        window = app.get_active_window() if app else None

        display = window.get_display() if window else None
        if display:
            theme = Gtk.IconTheme.get_for_display(display)
            theme_name = theme.get_theme_name() or 'hicolor'
        else:
            theme_name = 'hicolor'

        all_icons = self._scan_icons(theme_name)
        # Sort by name; place folder icons first
        sorted_icons = sorted(all_icons.items(), key=lambda kv: (
            0 if kv[0].startswith('folder') else 1, kv[0]
        ))

        dialog = Adw.Dialog()
        dialog.set_title('Choose Folder Icon')
        dialog.set_content_width(500)
        dialog.set_content_height(500)

        toolbar_view = Adw.ToolbarView()
        header = Adw.HeaderBar()

        reset_btn = Gtk.Button(label='Reset')
        reset_btn.add_css_class('destructive-action')
        reset_btn.connect('clicked', self._on_reset, folder_path, dialog)
        header.pack_start(reset_btn)

        toolbar_view.add_top_bar(header)

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)

        search = Gtk.SearchEntry()
        search.set_placeholder_text('Search icons...')
        search.set_margin_start(6)
        search.set_margin_end(6)
        search.set_margin_top(6)
        box.append(search)

        scrolled = Gtk.ScrolledWindow()
        scrolled.set_vexpand(True)

        flowbox = Gtk.FlowBox()
        flowbox.set_max_children_per_line(8)
        flowbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        flowbox.set_homogeneous(True)
        flowbox.set_activate_on_single_click(True)
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_margin_top(6)
        flowbox.set_margin_bottom(6)
        flowbox.set_margin_start(6)
        flowbox.set_margin_end(6)

        flowbox.connect('child-activated', self._on_icon_selected, folder_path, dialog)

        scrolled.set_child(flowbox)
        box.append(scrolled)
        toolbar_view.set_content(box)
        dialog.set_child(toolbar_view)

        state = {'timeout_id': 0}

        def rebuild(query):
            # Remove all children
            while True:
                child = flowbox.get_first_child()
                if not child:
                    break
                flowbox.remove(child)

            q = query.lower()
            count = 0
            for name, path in sorted_icons:
                if q and q not in name.lower():
                    continue
                image = Gtk.Image.new_from_file(path)
                image.set_pixel_size(48)
                image.set_name(path)
                image.set_tooltip_text(name)
                flowbox.append(image)
                count += 1
                if count >= 200:
                    break

        def on_search_changed(entry):
            if state['timeout_id']:
                GLib.source_remove(state['timeout_id'])
            state['timeout_id'] = GLib.timeout_add(200, do_search, entry.get_text().strip())

        def do_search(query):
            state['timeout_id'] = 0
            rebuild(query)
            return False

        search.connect('search-changed', on_search_changed)

        def on_map(_widget):
            search.grab_focus()

        search.connect('map', on_map)

        # Initial load: show folder icons + first batch
        rebuild('')

        dialog.present(window)

    def _on_icon_selected(self, flowbox, child, folder_path, dialog):
        image = child.get_child()
        icon_path = image.get_name()
        subprocess.run(['gio', 'set', folder_path, 'metadata::custom-icon', f'file://{icon_path}'])
        dialog.close()

    def _on_reset(self, button, folder_path, dialog):
        subprocess.run(['gio', 'set', '-t', 'unset', folder_path, 'metadata::custom-icon'])
        dialog.close()
