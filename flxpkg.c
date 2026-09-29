/*
 * FreeLinX Packages (flxpkg) - graphical front end for xpkg.
 *
 * Lists every package of the configured repositories with its installed
 * state, filters by text / installed / updates, and runs xpkg (install,
 * remove, update, upgrade) with the output shown live.  All the work is done
 * by xpkg itself; flxpkg only reads `xpkg query` and starts xpkg commands.
 * It runs as root through doas (see /etc/doas.conf), like flxnetmgr.
 */
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum { COL_STATE, COL_NAME, COL_VERSION, COL_INSTALLED, COL_SIZE, COL_DESC, COL_WEIGHT, NCOLS };
enum { SHOW_ALL, SHOW_INSTALLED, SHOW_UPDATES };

static GtkWidget *win, *search, *filter, *view, *logview, *status, *spinner;
static GtkWidget *btn_install, *btn_remove, *btn_update, *btn_upgrade;
static GtkListStore *store;
static GtkTreeModel *filtered;
static int running;
static char *last_query;
static int repo_rows;   /* rows that come from a repository index */

static void set_busy(int busy) {
    running = busy;
    gtk_widget_set_sensitive(btn_update, !busy);
    gtk_widget_set_sensitive(btn_upgrade, !busy);
    gtk_widget_set_sensitive(btn_install, !busy);
    gtk_widget_set_sensitive(btn_remove, !busy);
    if (busy) gtk_spinner_start(GTK_SPINNER(spinner));
    else gtk_spinner_stop(GTK_SPINNER(spinner));
}

static void log_append(const char *text) {
    GtkTextBuffer *b = gtk_text_view_get_buffer(GTK_TEXT_VIEW(logview));
    GtkTextIter end;
    gtk_text_buffer_get_end_iter(b, &end);
    /* drop terminal colour sequences */
    GString *clean = g_string_new(NULL);
    for (const char *p = text; *p; p++) {
        if (*p == '\033') { while (*p && *p != 'm') p++; if (!*p) break; continue; }
        if (*p == '\r') continue;
        g_string_append_c(clean, *p);
    }
    gtk_text_buffer_insert(b, &end, clean->str, -1);
    g_string_free(clean, TRUE);
    GtkTextMark *m = gtk_text_buffer_get_insert(b);
    gtk_text_buffer_get_end_iter(b, &end);
    gtk_text_buffer_place_cursor(b, &end);
    gtk_text_view_scroll_mark_onscreen(GTK_TEXT_VIEW(logview), m);
}

static void human(guint64 n, char *out, size_t sz) {
    if (n == 0) { snprintf(out, sz, "-"); return; }
    char *s = g_format_size(n);
    snprintf(out, sz, "%s", s);
    g_free(s);
}

/* newer-than check matching xpkg's rules closely enough for display */
static int is_update(const char *repo, const char *inst) {
    if (!*repo || !*inst) return 0;
    const char *a = repo, *b = inst;
    for (;;) {
        while (*a == '.' || *a == '-' || *a == '_') a++;
        while (*b == '.' || *b == '-' || *b == '_') b++;
        if (!*a || !*b) return *a != 0;
        char *ea, *eb;
        if (g_ascii_isdigit(*a) && g_ascii_isdigit(*b)) {
            guint64 x = g_ascii_strtoull(a, &ea, 10), y = g_ascii_strtoull(b, &eb, 10);
            if (x != y) return x > y;
            a = ea; b = eb;
        } else {
            size_t la = strcspn(a, ".-_"), lb = strcspn(b, ".-_");
            int c = strncmp(a, b, la < lb ? la : lb);
            if (c) return c > 0;
            if (la != lb) return la > lb;
            a += la; b += lb;
        }
    }
}

static void load_list(void) {
    gchar *out = NULL, *err = NULL;
    gint code = 0;
    const gchar *argv[] = { "xpkg", "query", NULL };
    gtk_list_store_clear(store);
    if (!g_spawn_sync(NULL, (gchar **)argv, NULL, G_SPAWN_SEARCH_PATH, NULL, NULL,
                      &out, &err, &code, NULL) || !out) {
        gtk_label_set_text(GTK_LABEL(status), "Cannot run xpkg.");
        return;
    }
    int total = 0, inst = 0, upd = 0;
    repo_rows = 0;
    gchar **lines = g_strsplit(out, "\n", -1);
    for (gchar **l = lines; *l; l++) {
        gchar **f = g_strsplit(*l, "\t", 5);
        if (g_strv_length(f) == 5) {
            char size[32];
            human(g_ascii_strtoull(f[3], NULL, 10), size, sizeof(size));
            int u = is_update(f[1], f[2]);
            const char *state = u ? "update" : (*f[2] ? "installed" : "");
            GtkTreeIter it;
            gtk_list_store_insert_with_values(store, &it, -1,
                COL_STATE, state, COL_NAME, f[0], COL_VERSION, *f[1] ? f[1] : f[2],
                COL_INSTALLED, f[2], COL_SIZE, size, COL_DESC, f[4],
                COL_WEIGHT, *f[2] ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL, -1);
            total++;
            if (*f[2]) inst++;
            if (u) upd++;
            if (*f[1]) repo_rows++;
        }
        g_strfreev(f);
    }
    g_strfreev(lines);
    char msg[160];
    if (repo_rows == 0)
        snprintf(msg, sizeof(msg), "No package list yet - press Refresh.");
    else
        snprintf(msg, sizeof(msg), "%d packages, %d installed, %d update%s available.",
                 total, inst, upd, upd == 1 ? "" : "s");
    gtk_label_set_text(GTK_LABEL(status), msg);
    g_free(out);
    g_free(err);
}

static gboolean row_visible(GtkTreeModel *m, GtkTreeIter *it, gpointer data) {
    (void)data;
    gchar *name, *desc, *state;
    gtk_tree_model_get(m, it, COL_NAME, &name, COL_DESC, &desc, COL_STATE, &state, -1);
    gboolean ok = TRUE;
    int mode = gtk_combo_box_get_active(GTK_COMBO_BOX(filter));
    if (mode == SHOW_INSTALLED && !(state && *state)) ok = FALSE;
    if (mode == SHOW_UPDATES && g_strcmp0(state, "update")) ok = FALSE;
    const char *q = gtk_entry_get_text(GTK_ENTRY(search));
    if (ok && q && *q) {
        gchar *lq = g_utf8_strdown(q, -1), *ln = g_utf8_strdown(name ? name : "", -1),
              *ld = g_utf8_strdown(desc ? desc : "", -1);
        ok = strstr(ln, lq) || strstr(ld, lq);
        g_free(lq); g_free(ln); g_free(ld);
    }
    g_free(name); g_free(desc); g_free(state);
    return ok;
}

static void refilter(void) {
    gtk_tree_model_filter_refilter(GTK_TREE_MODEL_FILTER(filtered));
}

static char *selected_name(char **installed) {
    GtkTreeSelection *sel = gtk_tree_view_get_selection(GTK_TREE_VIEW(view));
    GtkTreeModel *m;
    GtkTreeIter it;
    if (!gtk_tree_selection_get_selected(sel, &m, &it)) return NULL;
    char *name;
    gtk_tree_model_get(m, &it, COL_NAME, &name, COL_INSTALLED, installed, -1);
    return name;
}

static void update_buttons(void) {
    if (running) return;
    char *inst = NULL, *name = selected_name(&inst);
    gtk_widget_set_sensitive(btn_install, name != NULL);
    gtk_widget_set_sensitive(btn_remove, name && inst && *inst);
    gtk_button_set_label(GTK_BUTTON(btn_install), inst && *inst ? "Reinstall" : "Install");
    g_free(name);
    g_free(inst);
}

/* --- running xpkg ---------------------------------------------------------- */

static gboolean on_output(GIOChannel *ch, GIOCondition cond, gpointer data) {
    (void)data;
    gchar buf[4096];
    gsize n = 0;
    if (cond & (G_IO_IN | G_IO_PRI)) {
        GIOStatus st = g_io_channel_read_chars(ch, buf, sizeof(buf) - 1, &n, NULL);
        if (n > 0) { buf[n] = '\0'; log_append(buf); }
        if (st == G_IO_STATUS_NORMAL || st == G_IO_STATUS_AGAIN) return TRUE;
    }
    g_io_channel_unref(ch);
    return FALSE;
}

static void on_exit(GPid pid, gint wstatus, gpointer data) {
    g_spawn_close_pid(pid);
    gboolean ok = g_spawn_check_wait_status(wstatus, NULL);
    log_append(ok ? "\n-- done --\n\n" : "\n-- FAILED (see above) --\n\n");
    set_busy(0);
    load_list();
    refilter();
    update_buttons();
    gtk_label_set_text(GTK_LABEL(status), ok ? (const char *)data : "The last operation failed - see the log.");
}

static void run_xpkg(const char *what, const char *done, const char *a1, const char *a2) {
    if (running) return;
    const gchar *argv[6] = { "xpkg", "--yes", a1, a2, NULL, NULL };
    GPid pid;
    gint out, errfd;
    GError *e = NULL;
    char head[256];
    snprintf(head, sizeof(head), "$ xpkg %s%s%s\n", a1, a2 ? " " : "", a2 ? a2 : "");
    log_append(head);
    if (!g_spawn_async_with_pipes(NULL, (gchar **)argv, NULL,
                                  G_SPAWN_SEARCH_PATH | G_SPAWN_DO_NOT_REAP_CHILD,
                                  NULL, NULL, &pid, NULL, &out, &errfd, &e)) {
        log_append(e->message);
        log_append("\n");
        g_error_free(e);
        return;
    }
    set_busy(1);
    gtk_label_set_text(GTK_LABEL(status), what);
    int fds[2] = { out, errfd };
    for (int i = 0; i < 2; i++) {
        GIOChannel *ch = g_io_channel_unix_new(fds[i]);
        g_io_channel_set_encoding(ch, NULL, NULL);
        g_io_channel_set_close_on_unref(ch, TRUE);
        g_io_channel_set_flags(ch, G_IO_FLAG_NONBLOCK, NULL);
        g_io_add_watch(ch, G_IO_IN | G_IO_PRI | G_IO_HUP | G_IO_ERR, on_output, NULL);
    }
    g_child_watch_add(pid, on_exit, (gpointer)done);
}

static void on_install(GtkButton *b, gpointer d) {
    (void)b; (void)d;
    char *inst = NULL, *name = selected_name(&inst);
    if (!name) return;
    static char what[200];
    snprintf(what, sizeof(what), "Installing %s...", name);
    g_free(last_query);
    last_query = g_strdup(name);
    run_xpkg(what, "Installed.", inst && *inst ? "reinstall" : "install", last_query);
    g_free(name);
    g_free(inst);
}

static void on_remove(GtkButton *b, gpointer d) {
    (void)b; (void)d;
    char *inst = NULL, *name = selected_name(&inst);
    if (!name) return;
    GtkWidget *q = gtk_message_dialog_new(GTK_WINDOW(win), GTK_DIALOG_MODAL, GTK_MESSAGE_QUESTION,
                                          GTK_BUTTONS_OK_CANCEL, "Remove %s?", name);
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(q),
        "Its files are deleted. Settings you changed in /etc are kept.");
    int r = gtk_dialog_run(GTK_DIALOG(q));
    gtk_widget_destroy(q);
    if (r == GTK_RESPONSE_OK) {
        g_free(last_query);
        last_query = g_strdup(name);
        run_xpkg("Removing...", "Removed.", "remove", last_query);
    }
    g_free(name);
    g_free(inst);
}

static void on_update(GtkButton *b, gpointer d) {
    (void)b; (void)d;
    run_xpkg("Refreshing the package list...", "Package list refreshed.", "update", NULL);
}

static void on_upgrade(GtkButton *b, gpointer d) {
    (void)b; (void)d;
    run_xpkg("Upgrading the system...", "System up to date.", "upgrade", NULL);
}

static void on_row_activated(GtkTreeView *tv, GtkTreePath *p, GtkTreeViewColumn *c, gpointer d) {
    (void)tv; (void)p; (void)c; (void)d;
    on_install(NULL, NULL);
}

static GtkWidget *add_col(const char *title, int col, int expand) {
    GtkCellRenderer *r = gtk_cell_renderer_text_new();
    if (col == COL_DESC) g_object_set(r, "ellipsize", PANGO_ELLIPSIZE_END, NULL);
    if (col == COL_STATE) g_object_set(r, "foreground", "#2a7a2a", NULL);
    GtkTreeViewColumn *c = gtk_tree_view_column_new_with_attributes(title, r, "text", col, NULL);
    if (col == COL_NAME) gtk_tree_view_column_add_attribute(c, r, "weight", COL_WEIGHT);
    gtk_tree_view_column_set_sort_column_id(c, col);
    gtk_tree_view_column_set_resizable(c, TRUE);
    gtk_tree_view_column_set_expand(c, expand);
    gtk_tree_view_append_column(GTK_TREE_VIEW(view), c);
    return GTK_WIDGET(c);
}

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    if (geteuid() != 0) {
        /* start ourselves through doas; the wheel rule needs no password */
        execlp("doas", "doas", "-n", "/usr/bin/flxpkg", (char *)NULL);
        GtkWidget *d = gtk_message_dialog_new(NULL, 0, GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
            "Packages needs administrator rights.");
        gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(d),
            "Your account must be in the wheel group.");
        gtk_dialog_run(GTK_DIALOG(d));
        return 1;
    }

    win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_window_set_title(GTK_WINDOW(win), "Packages");
    gtk_window_set_default_size(GTK_WINDOW(win), 900, 600);
    gtk_window_set_icon_name(GTK_WINDOW(win), "system-software-install");
    g_signal_connect(win, "destroy", G_CALLBACK(gtk_main_quit), NULL);

    GtkWidget *vb = gtk_box_new(GTK_ORIENTATION_VERTICAL, 6);
    gtk_container_set_border_width(GTK_CONTAINER(vb), 8);
    gtk_container_add(GTK_CONTAINER(win), vb);

    GtkWidget *top = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    search = gtk_search_entry_new();
    gtk_entry_set_placeholder_text(GTK_ENTRY(search), "Search packages");
    gtk_box_pack_start(GTK_BOX(top), search, TRUE, TRUE, 0);
    filter = gtk_combo_box_text_new();
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(filter), "All packages");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(filter), "Installed");
    gtk_combo_box_text_append_text(GTK_COMBO_BOX_TEXT(filter), "Updates");
    gtk_combo_box_set_active(GTK_COMBO_BOX(filter), SHOW_ALL);
    gtk_box_pack_start(GTK_BOX(top), filter, FALSE, FALSE, 0);
    btn_update = gtk_button_new_with_label("Refresh");
    btn_upgrade = gtk_button_new_with_label("Upgrade all");
    gtk_box_pack_start(GTK_BOX(top), btn_update, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(top), btn_upgrade, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vb), top, FALSE, FALSE, 0);

    store = gtk_list_store_new(NCOLS, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING, G_TYPE_STRING,
                               G_TYPE_STRING, G_TYPE_STRING, G_TYPE_INT);
    filtered = gtk_tree_model_filter_new(GTK_TREE_MODEL(store), NULL);
    gtk_tree_model_filter_set_visible_func(GTK_TREE_MODEL_FILTER(filtered), row_visible, NULL, NULL);
    GtkTreeModel *sorted = gtk_tree_model_sort_new_with_model(filtered);
    gtk_tree_sortable_set_sort_column_id(GTK_TREE_SORTABLE(sorted), COL_NAME, GTK_SORT_ASCENDING);
    view = gtk_tree_view_new_with_model(sorted);
    gtk_tree_view_set_enable_search(GTK_TREE_VIEW(view), FALSE);
    add_col("", COL_STATE, FALSE);
    add_col("Name", COL_NAME, FALSE);
    add_col("Version", COL_VERSION, FALSE);
    add_col("Installed", COL_INSTALLED, FALSE);
    add_col("Download", COL_SIZE, FALSE);
    add_col("Description", COL_DESC, TRUE);
    GtkWidget *sw = gtk_scrolled_window_new(NULL, NULL);
    gtk_container_add(GTK_CONTAINER(sw), view);
    gtk_box_pack_start(GTK_BOX(vb), sw, TRUE, TRUE, 0);

    GtkWidget *actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6);
    spinner = gtk_spinner_new();
    status = gtk_label_new("");
    gtk_label_set_xalign(GTK_LABEL(status), 0);
    btn_install = gtk_button_new_with_label("Install");
    btn_remove = gtk_button_new_with_label("Remove");
    gtk_box_pack_start(GTK_BOX(actions), spinner, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(actions), status, TRUE, TRUE, 0);
    gtk_box_pack_end(GTK_BOX(actions), btn_remove, FALSE, FALSE, 0);
    gtk_box_pack_end(GTK_BOX(actions), btn_install, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(vb), actions, FALSE, FALSE, 0);

    GtkWidget *exp = gtk_expander_new("Details");
    logview = gtk_text_view_new();
    gtk_text_view_set_editable(GTK_TEXT_VIEW(logview), FALSE);
    gtk_text_view_set_monospace(GTK_TEXT_VIEW(logview), TRUE);
    GtkWidget *lsw = gtk_scrolled_window_new(NULL, NULL);
    gtk_widget_set_size_request(lsw, -1, 140);
    gtk_container_add(GTK_CONTAINER(lsw), logview);
    gtk_container_add(GTK_CONTAINER(exp), lsw);
    gtk_box_pack_start(GTK_BOX(vb), exp, FALSE, FALSE, 0);

    g_signal_connect(search, "search-changed", G_CALLBACK(refilter), NULL);
    g_signal_connect(filter, "changed", G_CALLBACK(refilter), NULL);
    g_signal_connect(btn_install, "clicked", G_CALLBACK(on_install), NULL);
    g_signal_connect(btn_remove, "clicked", G_CALLBACK(on_remove), NULL);
    g_signal_connect(btn_update, "clicked", G_CALLBACK(on_update), NULL);
    g_signal_connect(btn_upgrade, "clicked", G_CALLBACK(on_upgrade), NULL);
    g_signal_connect(view, "row-activated", G_CALLBACK(on_row_activated), NULL);
    g_signal_connect(gtk_tree_view_get_selection(GTK_TREE_VIEW(view)), "changed",
                     G_CALLBACK(update_buttons), NULL);

    gtk_widget_show_all(win);
    load_list();
    update_buttons();
    /* first start: no index cached yet */
    if (repo_rows == 0)
        on_update(NULL, NULL);
    gtk_main();
    return 0;
}
