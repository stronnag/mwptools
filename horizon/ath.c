#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <math.h>
#include <glib.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#include <string.h>
#include <gtk/gtk.h>
#include "gtkartificialhorizon.h"

static GIOChannel *gio;
static guint tag;
static  GtkWidget *art_hor;
static GdkWindow *sockwin = 0;
static GtkWidget *window;
static GdkColor color;
static GdkColor *pcol;

static gboolean read_data(GIOChannel *source, GIOCondition condition, gpointer data)
{
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
        gtk_main_quit();
        return FALSE;
    }
}

static guint create_plug();

static void invoke_horizon()
{
    art_hor = gtk_artificial_horizon_new();
    g_object_set(GTK_ARTIFICIAL_HORIZON (art_hor),
                 "grayscale-color", FALSE,
                 "radial-color", TRUE, NULL);
    gtk_container_add(GTK_CONTAINER (window), art_hor);
    if(pcol)
        gtk_widget_modify_bg(art_hor, GTK_STATE_NORMAL, pcol);
    gtk_widget_show_all(window);
}

static void publish_plug(guint plg)
{
    char buf[32];
    sprintf(buf, "%d\n", plg);
    (void)write(fileno(stdout), buf, strlen(buf));
//    fprintf(stderr, "sent plugin %d\n", plg);
}

static void plug_fail(GtkPlug * w, gpointer d)
{
    guint plg = create_plug();
    invoke_horizon();
    publish_plug(plg);
}

static guint create_plug()
{
    window =( GtkWidget *)gtk_plug_new (0);
    g_signal_connect (window, "destroy", G_CALLBACK(plug_fail), NULL);
    guint plg = gtk_plug_get_id (GTK_PLUG(window));
    return plg;
}

int  main(int argc, char ** argv)
{
    guint plg = 0;
    gtk_init (&argc, &argv);

    gio = g_io_channel_unix_new(0);
    tag = g_io_add_watch (gio, G_IO_IN|G_IO_HUP|G_IO_ERR|G_IO_NVAL, read_data, NULL);
    if(argc > 2)
    {
        plg  = create_plug();
    }
    else
    {
        window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        g_signal_connect (window, "destroy", G_CALLBACK (gtk_main_quit), NULL);
    }

    if(argc > 1 && argv[argc-1][0] == '#')
    {
        gdk_color_parse (argv[argc-1], &color);
        pcol = &color;
    }

    invoke_horizon();

    if(plg != 0)
    {
        publish_plug(plg);
    }
    gtk_main();
    return 0;
}
