#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <math.h>
#include <glib.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#include <gtk/gtk.h>
#include "gtkartificialhorizon.h"

static GIOChannel *gio;
static guint tag;

gboolean read_data(GIOChannel *source, GIOCondition condition, gpointer data)
{
    GtkWidget *art_hor =  (GtkWidget *)data;
    if((condition &  G_IO_IN) ==  G_IO_IN)
    {
        double d1, d2;
        gchar *str;
        GIOStatus res = g_io_channel_read_line(gio, &str, NULL, NULL, NULL);
        if(res == G_IO_STATUS_NORMAL)
        {
            char *endp;
            d1 = g_ascii_strtod(str, &endp);
            d2 = g_ascii_strtod(endp, &endp);
            g_free(str);

            if(d1 > 360)
                d1 = 360;
            if(d1 < 0)
                d1 = 0;

            if(d2 > 70)
                d2 = 70;
            if(d2 < -70)
                d2 = -70;

            gtk_artificial_horizon_set_value (
                GTK_ARTIFICIAL_HORIZON (art_hor), d1, d2);
            gtk_artificial_horizon_redraw(GTK_ARTIFICIAL_HORIZON(art_hor));
        }
        return TRUE;
    }
    else
    {
        g_source_remove (tag);
        return FALSE;
    }
}

int main(int argc, char ** argv)
{

  GtkWidget *art_hor;
  GtkWidget *vbox;
  int sockid = 0;
  GtkWidget *window;
  gtk_init (&argc, &argv);

  if(argc == 2)
  {
      sockid = strtol(argv[1], NULL, 0);
      window =( GtkWidget *)gtk_plug_new (sockid);
  }
  else
  {
      window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
  }

  vbox = gtk_vbox_new(TRUE, 1);
  gtk_container_add(GTK_CONTAINER (window), vbox);
  art_hor = gtk_artificial_horizon_new();
  g_object_set(GTK_ARTIFICIAL_HORIZON (art_hor),
               "grayscale-color", FALSE,
               "radial-color", TRUE, NULL);

  gtk_box_pack_start(GTK_BOX(vbox), GTK_WIDGET(art_hor), TRUE, TRUE, 0);
  gtk_widget_show_all(window);
  gio = g_io_channel_unix_new(0);
  tag = g_io_add_watch (gio,
                        G_IO_IN|G_IO_HUP|G_IO_ERR|G_IO_NVAL,
                        read_data, art_hor);
  gtk_main();
  return 0;
}
