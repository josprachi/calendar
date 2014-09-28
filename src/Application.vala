//
//  Copyright (C) 2011-2012 Maxwell Barvian
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

namespace Maya {

    namespace Option {

        private static bool ADD_EVENT = false;
        private static bool IMPORT_CALENDAR = false;
        private static bool PRINT_VERSION = false;

    }

    public static int main (string[] args) {

        var context = new OptionContext (_("Calendar"));
        context.add_main_entries (Application.app_options, "maya");
        context.add_group (Gtk.get_option_group (true));

        try {
            context.parse (ref args);
        } catch (Error e) {
            warning (e.message);
        }

        if (Option.PRINT_VERSION) {
            stdout.printf("Maya %s\n", Build.VERSION);
            stdout.printf("Copyright 2011-2014 Maya Developers.\n");
            return 0;
        }

        Gtk.init (ref args);
        Clutter.init (ref args);
        var app = new Application ();

        return app.run (args);

    }

    /**
     * Main application class.
     */
    public class Application : Granite.Application {

        /**
         * Initializes environment variables
         */
        construct {

            // App info
            build_data_dir = Build.DATADIR;
            build_pkg_data_dir = Build.PKGDATADIR;
            build_release_name = Build.RELEASE_NAME;
            build_version = Build.VERSION;
            build_version_info = Build.VERSION_INFO;

            program_name = _(Build.APP_NAME);
            exec_name = "maya-calendar";

            app_years = "2011-2014";
            application_id = "net.launchpad.maya";
            app_icon = "office-calendar";
            app_launcher = "maya-calendar.desktop";

            main_url = "https://launchpad.net/maya";
            bug_url = "https://bugs.launchpad.net/maya";
            help_url = "http://elementaryos.org/answers/+/maya/all/newest";
            translate_url = "https://translations.launchpad.net/maya";

            about_authors = {
                "Maxwell Barvian <maxwell@elementaryos.org>",
                "Jaap Broekhuizen <jaapz.b@gmail.com>",
                "Avi Romanoff <aviromanoff@gmail.com>",
                "Allen Lowe <lallenlowe@gmail.com>",
                "Niels Avonds <niels.avonds@gmail.com>",
                "Corentin Noël <tintou@mailoo.org>"
            };
            about_documenters = {
                "Maxwell Barvian <maxwell@elementaryos.org>"
            };
            about_artists = {
                "Daniel Foré <bunny@go-docky.com>"
            };
            about_translators = "Launchpad Translators";
            about_license_type = Gtk.License.GPL_3_0;
        }

        public static const OptionEntry[] app_options = {
            { "add-event", 'a', 0, OptionArg.NONE, out Option.ADD_EVENT, "Show an add event dialog", null },
            { "import-ical", 'i', 0, OptionArg.STRING, out Option.IMPORT_CALENDAR, "Import quickly an ical", null },
            { "version", 'v', 0, OptionArg.NONE, out Option.PRINT_VERSION, "Print version info and exit", null },
            { null }
        };

        public Gtk.Window window;
        View.MayaToolbar toolbar;
        View.CalendarView calview;
        View.Sidebar sidebar;
        Gtk.Paned hpaned;
        Gtk.Grid gridcontainer;
        Gtk.InfoBar infobar;
        Gtk.Label infobar_label;

        /**
         * Called when the application is activated.
         */
        protected override void activate () {
            if (get_windows () != null) {
                get_windows ().data.present (); // present window if app is already running
                return;
            }

            var calmodel = Model.CalendarModel.get_default ();
            calmodel.load_all_sources ();

            init_gui ();
            window.show_all ();

            if (Option.ADD_EVENT) {
                on_tb_add_clicked (calview.selected_date);
            }

            Gtk.main ();
        }

        /**
         * Initializes the graphical window and its components
         */
        void init_gui () {
            create_window ();
            var saved_state = Settings.SavedState.get_default ();

            sidebar = new View.Sidebar ();
            // Don't automatically display all the widgets on the sidebar
            sidebar.no_show_all = true;
            sidebar.show ();
            sidebar.event_removed.connect (on_remove);
            sidebar.event_modified.connect (on_modified);
            sidebar.agenda_view.shown_changed.connect (on_agenda_view_shown_changed);
            sidebar.set_size_request(160,0);

            calview = new View.CalendarView ();
            calview.vexpand = true;
            calview.on_event_add.connect ((date) => on_tb_add_clicked (date));
            calview.selection_changed.connect ((date) => sidebar.set_selected_date (date));

            gridcontainer = new Gtk.Grid ();
            gridcontainer.orientation = Gtk.Orientation.VERTICAL;

            hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            hpaned.pack1 (calview, true, false);
            hpaned.pack2 (sidebar, true, false);
            hpaned.position = saved_state.hpaned_position;

            infobar_label = new Gtk.Label (null);
            infobar_label.show ();
            infobar = new Gtk.InfoBar ();
            infobar.message_type = Gtk.MessageType.ERROR;
            infobar.show_close_button = true;
            infobar.get_content_area ().add (infobar_label);
            infobar.no_show_all = true;
            infobar.response.connect ((id) => infobar.hide ());
            Model.CalendarModel.get_default ().error_received.connect ((message) => {
                Idle.add (() => {
                    infobar_label.label = message;
                    infobar.show ();
                    return false;
                });
            });

            gridcontainer.add (infobar);
            gridcontainer.add (hpaned);
            window.add (gridcontainer);

            add_window (window);

            if (saved_state.window_state == Settings.WindowState.MAXIMIZED)
                window.maximize ();
        }

        void on_agenda_view_shown_changed (bool old, bool shown) {
            toolbar.search_bar.sensitive = shown;
        }

        /**
         * Called when the remove button is selected.
         */
        void on_remove (E.CalComponent comp) {
            Model.CalendarModel.get_default ().remove_event (comp.get_data<E.Source> ("source"), comp, E.CalObjModType.THIS);
        }

        /**
         * Called when the edit button is selected.
         */
        void on_modified (E.CalComponent comp) {
            var dialog = new Maya.View.EventDialog (window, comp, comp.get_data<E.Source> ("source"), null);
            dialog.present ();
        }

        /**
         * Creates the main window.
         */
        void create_window () {
            var saved_state = Settings.SavedState.get_default ();
            window = new Gtk.Window ();
            window.title = program_name;
            window.icon_name = "office-calendar";
            window.set_size_request (625, 400);
            window.default_width = saved_state.window_width;
            window.default_height = saved_state.window_height;
            window.window_position = Gtk.WindowPosition.CENTER;

            window.delete_event.connect (on_window_delete_event);
            window.destroy.connect (on_quit);
            window.key_press_event.connect ((e) => {
                switch (e.keyval) {
                    case Gdk.Key.@q:
                    case Gdk.Key.@w:
                        if ((e.state & Gdk.ModifierType.CONTROL_MASK) != 0) {
                            window.destroy ();
                        }

                        break;
                    }

                    return false;
            });

            toolbar = new View.MayaToolbar ();
            toolbar.add_calendar_clicked.connect (() => on_tb_add_clicked (calview.selected_date));
            toolbar.on_menu_today_toggled.connect (on_menu_today_toggled);
            toolbar.on_search.connect ((text) => on_search (text));
            window.set_titlebar (toolbar);
        }
        
        void on_quit () {
            Model.CalendarModel.get_default ().do_real_deletion ();
            Gtk.main_quit ();
        }

        void update_saved_state () {

            debug("Updating saved state");

            // Save window state
            var saved_state = Settings.SavedState.get_default ();
            if ((window.get_window ().get_state () & Settings.WindowState.MAXIMIZED) != 0)
                saved_state.window_state = Settings.WindowState.MAXIMIZED;
            else
                saved_state.window_state = Settings.WindowState.NORMAL;

            // Save window size
            if (saved_state.window_state == Settings.WindowState.NORMAL) {
                int width, height;
                window.get_size (out width, out height);
                saved_state.window_width = width;
                saved_state.window_height = height;
            }

            saved_state.hpaned_position = hpaned.position;
        }

        //--- SIGNAL HANDLERS ---//

        bool on_window_delete_event (Gdk.EventAny event) {
            update_saved_state ();
            return false;
        }

        void on_tb_add_clicked (DateTime dt) {
            var dialog = new Maya.View.EventDialog (window, null, null, dt);
            dialog.show_all ();
        }

        /**
         * Called when the search_bar is used.
         */
        void on_search (string text) {
            sidebar.set_search_text (text);
        }

        void on_menu_today_toggled () {
            calview.today ();
        }

    }

}