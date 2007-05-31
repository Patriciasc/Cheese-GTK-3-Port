/*
 * Copyright (C) 2007 daniel g. siegel <dgsiegel@gmail.com>
 * All rights reserved. This software is released under the GPL2 licence.
 */

#include <libgnomevfs/gnome-vfs.h>
#include <glib/gprintf.h>

#include "cheese.h"
#include "fileutil.h"
#include "thumbnails.h"
#include "window.h"

struct _thumbnails thumbnails;

void
create_thumbnails_store() {
  thumbnails.store = gtk_list_store_new(1, GDK_TYPE_PIXBUF);
}

void
append_photo(gchar *filename) {
  g_printf("appending %s to thumbnail row\n", filename);
  gtk_list_store_append(thumbnails.store, &thumbnails.iter);
  GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file_at_size(filename, THUMB_WIDTH, THUMB_HEIGHT, NULL);
  if (!pixbuf) {
    g_warning("could not load %s\n", filename);
    return;
  }
  gtk_list_store_set(thumbnails.store, &thumbnails.iter, 0, pixbuf, -1);
  g_object_unref(pixbuf);
}

void
remove_photo(gchar *filename) {

  //gtk_tree_model_get_iter(GTK_TREE_MODEL(store), &iter, gtk_tree_path_new_from_string(path));
  //gtk_list_store_remove(store, &iter);
  //if (is_file_in_list_store(store, info_uri, &iter)) {
  //    gtk_list_store_remove(GTK_LIST_STORE(store), &iter);
}

void
fill_thumbs()
{
  GDir *dir;
  gchar *path;
  const gchar *name;
  gboolean is_dir;
  
  gtk_list_store_clear(thumbnails.store);

  dir = g_dir_open(get_cheese_path(), 0, NULL);
  if (!dir)
    return;

  name = g_dir_read_name(dir);
  while (name != NULL) {
    if (name[0] != '.') {
      path = g_build_filename(get_cheese_path(), name, NULL);

      is_dir = g_file_test(path, G_FILE_TEST_IS_DIR);

      if (!is_dir)
        append_photo(path);
      g_free(path);
    }
    name = g_dir_read_name(dir);      
  }
  g_free(dir);
}
