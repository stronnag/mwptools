/*
 * Gtk Artificial Horizon Widget
 * Copyright (C) 2010, CCNY Robotics Lab
 * Gautier Dumonteil <gautier.dumonteil@gmail.com>
 * http://robotics.ccny.cuny.edu
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 */

/**
 * @file gtkartificialhorizon.c
 * @brief Gtk+ based Artificial Horizon Widget
 * @author Gautier Dumonteil <gautier.dumonteil@gmail.com>
 * @version 0.2
 * @date 02/09/2010
 *
 * Gtk Artificial Horizon Widget <br>
 * Copyright (C) 2010, CCNY Robotics Lab <br>
 * http://robotics.ccny.cuny.edu <br>
 *
 * This widget provide an easy to read artificial horizon instrument. <br>
 * The design is volontary based on a real artificial horizon flight instrument <br>
 * in order to be familiar to aircraft and helicopter pilots.<br>
 *
 * @b Pictures:<br>
 * <table><tr>
 * <th><IMG SRC="http://www.ros.org/wiki/ground_station?action=AttachFile&do=get&target=gtkartificialhorizon.png"></th>
 * <th><IMG SRC="http://www.ros.org/wiki/ground_station?action=AttachFile&do=get&target=gtkartificialhorizon_g.png"></th>
 * </tr></table>
 *
 * @b Example: <br>
 * Add Artificial Horizon widget to an gtkvbox and set some params <br>
 * @code
 * window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
 * vbox = gtk_vbox_new(TRUE, 1);
 * gtk_container_add(GTK_CONTAINER (window), vbox);
 *
 * art_hor = gtk_artificial_horizon_new();
 * g_object_set(GTK_ARTIFICIAL_HORIZON (art_hor),
 *		"grayscale-color", false,
 *		"radial-color", true, NULL);
 *
 * gtk_box_pack_start(GTK_BOX(vbox), GTK_WIDGET(art_hor), TRUE, TRUE, 0);
 * gtk_widget_show_all(window);
 * @endcode
 *
 * The following code show how to change widget's values and redraw it:<br>
 * Note that here tc's type is "GtkWidget *".<br>
 * @code
 * if (IS_GTK_ARTIFICIAL_HORIZON (art_hor))
 * {
 *	gtk_artificial_horizon_set_value (GTK_ARTIFICIAL_HORIZON (art_hor), rotation_angle,trans_y);
 *	gtk_artificial_horizon_redraw(GTK_ARTIFICIAL_HORIZON(art_hor));
 * }
 * @endcode
 *
  @b Widget @b Parameters:<br>
 * - "grayscale-colors": boolean, if TRUE, draw the widget with grayscale colors (outdoor use)<br>
 * - "radial-color": boolean, if TRUE, draw a fake light reflexion<br>
 *
 * @b Widget @b values:<br>
 * - "rotation_angle": double, provide rotation of the widget sphere<br>
 * and external arc - the value is from 0 to 360.<br>
 * - "trans_y": double, provide sphere translation - the value is from -70 to 70
 */

#include "gtkartificialhorizon.h"

/**
 * @typedef struct GtkArtificialHorizonPrivate
 * @brief Special Gtk API strucure. Allow to add a private data<br>
 * for the widget. Defined in the C file in order to be private.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
typedef struct _GtkArtificialHorizonPrivate
{
   /* cairo data */
  gboolean draw_once;
  cairo_surface_t * static_surface;
  cairo_surface_t * dynamic_surface;
  cairo_surface_t * g_pat_surface;

  /* widget data */
  gint unit_value;
  gboolean grayscale_color;
  gboolean radial_color;
  gdouble angle;
  gdouble trans_y;

  /* drawing data */
  gdouble x;
  gdouble y;
  gdouble radius;
  GdkColor bg_color_inv;
  GdkColor bg_color_artificialhorizon;
  GdkColor bg_color_bounderie;
  GdkColor bg_radial_color_begin_artificialhorizon;
  GdkColor bg_radial_color_begin_bounderie;

  /* mouse information */
  gboolean b_mouse_onoff;
  GdkPoint mouse_pos;
  GdkModifierType mouse_state;

} GtkArtificialHorizonPrivate;

/**
 * @enum _GTK_ARTIFICIAL_HORIZON_PROPERTY_ID
 * @brief Special Gtk API enum. Allow to identify widget's properties.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
enum _GTK_ARTIFICIAL_HORIZON_PROPERTY_ID
{
  PROP_0,
  PROP_GRAYSCALE_COLOR,
  PROP_UNIT_IS_FEET,
  PROP_UNIT_STEP_VALUE,
  PROP_RADIAL_COLOR,
} GTK_ARTIFICIAL_HORIZON_PROPERTY_ID;

/**
 * @fn G_DEFINE_TYPE (GtkArtificialHorizon, gtk_artificial_horizon, GTK_TYPE_DRAWING_AREA);
 * @brief Special Gtk API function. Define a new object type named GtkArtificialHorizon <br>
 * and all preface of the widget's functions calls with gtk_artificial_horizon.<br>
 * We are inheriting the type of GtkDrawingArea.<br>
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
G_DEFINE_TYPE (GtkArtificialHorizon, gtk_artificial_horizon, GTK_TYPE_DRAWING_AREA);

/**
 * @def GTK_ARTIFICIAL_HORIZON_GET_PRIVATE(obj) (G_TYPE_INSTANCE_GET_PRIVATE ((obj), GTK_ARTIFICIAL_HORIZON_TYPE, GtkArtificialHorizonPrivate))
 * @brief Special Gtk API define. Add a macro for easy access to the private<br>
 * data struct.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
#define GTK_ARTIFICIAL_HORIZON_GET_PRIVATE(obj) (G_TYPE_INSTANCE_GET_PRIVATE ((obj), GTK_ARTIFICIAL_HORIZON_TYPE, GtkArtificialHorizonPrivate))

static void gtk_artificial_horizon_class_init (GtkArtificialHorizonClass * klass);
static void gtk_artificial_horizon_init (GtkArtificialHorizon * arh);
static void gtk_artificial_horizon_destroy (GtkObject * object);
static void gtk_artificial_horizon_set_property (GObject * object, guint prop_id, const GValue * value,
                                                 GParamSpec * pspec);

static gboolean gtk_artificial_horizon_configure_event (GtkWidget * widget, GdkEventConfigure * event);
static gboolean gtk_artificial_horizon_expose (GtkWidget * graph, GdkEventExpose * event);
static gboolean gtk_artificial_horizon_button_press_event (GtkWidget * widget, GdkEventButton * ev);


static void gtk_artificial_horizon_draw_static (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_base (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_screws (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_grayscale_pattern (GtkWidget * arh, cairo_t * cr);

static void gtk_artificial_horizon_draw_dynamic (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_external_arc (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_internal_sphere (GtkWidget * alt, cairo_t * cr);
static void gtk_artificial_horizon_draw_upper_base (GtkWidget * alt, cairo_t * cr);

static gboolean gtk_artificial_horizon_debug = FALSE;
static gboolean gtk_artificial_horizon_lock_update = FALSE;

/**
 * @fn static void gtk_artificial_horizon_class_init (GtkArtificialHorizonClass * klass)
 * @brief Special Gtk API function. Function called when the class is<br>
 * initialised. Allow to set certain class wide functions and<br>
 * properties<br>.
 * Allow to override some parent’s expose handler like :<br>
 * - set_property handler<br>
 * - destroy handler<br>
 * - configure_event handler<br>
 * - motion_notify_event handler (not use in this widget)
 * - button_press_event handler (not use in this widget)
 *
 * Also register the private struct GtkArtificialHorizonPrivate with<br>
 * the class and install widget properties.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_class_init (GtkArtificialHorizonClass * klass)
{
  GObjectClass *obj_class = G_OBJECT_CLASS (klass);
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);
  GtkObjectClass *gtkobject_class = GTK_OBJECT_CLASS (klass);

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_class_init()");
  }

  /* GObject signal overrides */
  obj_class->set_property = gtk_artificial_horizon_set_property;

  /* GtkObject signal overrides */
  gtkobject_class->destroy = gtk_artificial_horizon_destroy;

  /* GtkWidget signals overrides */
  widget_class->configure_event = gtk_artificial_horizon_configure_event;
  widget_class->expose_event = gtk_artificial_horizon_expose;
  widget_class->button_press_event = gtk_artificial_horizon_button_press_event;

  g_type_class_add_private (obj_class, sizeof (GtkArtificialHorizonPrivate));

  g_object_class_install_property (obj_class,
                                   PROP_GRAYSCALE_COLOR,
                                   g_param_spec_boolean ("grayscale-color",
                                                         "use grayscale for the widget color",
                                                         "use grayscale for the widget color", FALSE,
                                                         G_PARAM_WRITABLE));
  g_object_class_install_property (obj_class,
                                   PROP_RADIAL_COLOR,
                                   g_param_spec_boolean ("radial-color",
                                                         "the widget use radial color",
                                                         "the widget use radial color", TRUE, G_PARAM_WRITABLE));
  return;
}

/**
 * @fn static void gtk_artificial_horizon_init (GtkArtificialHorizon * arh)
 * @brief Special Gtk API function. Function called when the creating a<br>
 * new GtkArtificialHorizon. Allow to initialize some private variables of<br>
 * widget.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_init (GtkArtificialHorizon * arh)
{
  GtkArtificialHorizonPrivate *priv = NULL;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_init()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  gtk_widget_add_events (GTK_WIDGET (arh), GDK_BUTTON_PRESS_MASK |
                         GDK_BUTTON_RELEASE_MASK | GDK_POINTER_MOTION_MASK | GDK_POINTER_MOTION_HINT_MASK);
  priv->b_mouse_onoff = FALSE;
  priv->draw_once = FALSE;
  priv->grayscale_color = FALSE;
  priv->radial_color = TRUE;
  priv->angle = 0;
  priv->trans_y = 0;

  priv->bg_color_bounderie.red = 6553.5;        // 0.1 cairo
  priv->bg_color_bounderie.green = 6553.5;
  priv->bg_color_bounderie.blue = 6553.5;
  priv->bg_color_artificialhorizon.red = 3276.75;       // 0.05 cairo
  priv->bg_color_artificialhorizon.green = 3276.75;
  priv->bg_color_artificialhorizon.blue = 3276.75;
  priv->bg_color_inv.red = 45874.5;     // 0.7 cairo
  priv->bg_color_inv.green = 45874.5;
  priv->bg_color_inv.blue = 45874.5;
  priv->bg_radial_color_begin_bounderie.red = 13107;    // 0.2 cairo
  priv->bg_radial_color_begin_bounderie.green = 13107;
  priv->bg_radial_color_begin_bounderie.blue = 13107;
  priv->bg_radial_color_begin_artificialhorizon.red = 45874.5;  // 0.7 cairo
  priv->bg_radial_color_begin_artificialhorizon.green = 45874.5;
  priv->bg_radial_color_begin_artificialhorizon.blue = 45874.5;
  return;
}

/**
 * @fn static gboolean gtk_artificial_horizon_configure_event (GtkWidget * widget, GdkEventConfigure * event)
 * @brief Special Gtk API function. Override the _configure_event handler<br>
 * in order to resize the widget when the main window is resized.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static gboolean gtk_artificial_horizon_configure_event (GtkWidget * widget, GdkEventConfigure * event)
{
  GtkArtificialHorizonPrivate *priv;
  GtkArtificialHorizon *arh = GTK_ARTIFICIAL_HORIZON (widget);

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_configure_event()");
  }
  g_return_val_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh), FALSE);
  g_return_val_if_fail (event->type == GDK_CONFIGURE, FALSE);

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);
  g_return_val_if_fail (priv != NULL, FALSE);

  priv->draw_once = FALSE;

  return FALSE;
}

/**
 * @fn static gboolean gtk_artificial_horizon_expose (GtkWidget * arh, GdkEventExpose * event)
 * @brief Special Gtk API function. Override of the expose handler.<br>
 * An “expose-event” signal is emitted when the widget need to be drawn.<br>
 * A Cairo context is created for the parent's GdkWindow.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static gboolean gtk_artificial_horizon_expose (GtkWidget * arh, GdkEventExpose * event)
{
  GtkArtificialHorizonPrivate *priv;
  GtkWidget *widget = arh;
  cairo_t * cr_g_pat;
  cairo_t * cr_final;
  cairo_t * cr_static;
  cairo_t * cr_dynamic;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_expose()");
  }
  g_return_val_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh), FALSE);

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);
  g_return_val_if_fail (priv != NULL, FALSE);

  cr_final = gdk_cairo_create (widget->window);

  if(!priv->draw_once)
  {
		priv->static_surface = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, event->area.width, event->area.height);
		cr_static = cairo_create(priv->static_surface);

		cairo_rectangle (cr_static, event->area.x, event->area.y, event->area.width, event->area.height);
		cairo_clip (cr_static);
		gtk_artificial_horizon_draw_static (arh,cr_static);
		cairo_destroy (cr_static);

		priv->g_pat_surface = cairo_surface_create_similar (priv->static_surface,CAIRO_CONTENT_COLOR_ALPHA,event->area.width, event->area.height);
		cr_g_pat = cairo_create(priv->g_pat_surface);
		cairo_rectangle (cr_g_pat, event->area.x, event->area.y, event->area.width, event->area.height);
		cairo_clip (cr_g_pat);
		gtk_artificial_horizon_draw_grayscale_pattern (arh, cr_g_pat);
		cairo_destroy (cr_g_pat);

		priv->draw_once=TRUE;
  }

  priv->dynamic_surface = cairo_surface_create_similar (priv->static_surface,CAIRO_CONTENT_COLOR_ALPHA,event->area.width, event->area.height);
  cr_dynamic = cairo_create(priv->dynamic_surface);
  cairo_rectangle (cr_dynamic, event->area.x, event->area.y, event->area.width, event->area.height);
  cairo_clip (cr_dynamic);
  gtk_artificial_horizon_draw_dynamic (arh, cr_dynamic);
  cairo_destroy (cr_dynamic);

  cairo_set_source_surface(cr_final, priv->static_surface, 0, 0);
  cairo_paint(cr_final);
  cairo_set_source_surface(cr_final, priv->dynamic_surface, 0, 0);
  cairo_paint(cr_final);
  cairo_set_source_surface(cr_final, priv->g_pat_surface, 0, 0);
  cairo_paint(cr_final);

  cairo_surface_destroy(priv->dynamic_surface);
  cairo_destroy (cr_final);
  return FALSE;
}

/**
 * @fn extern void gtk_artificial_horizon_redraw (GtkArtificialHorizon * arh)
 * @brief Special Gtk API function. Redraw the widget when called.
 *
 * This function will redraw the widget canvas. In order to reexpose the canvas<br>
 * (and cause it to redraw) of our parent class(GtkDrawingArea), it is needed to<br>
 * use gdk_window_invalidate_rect(). The function gdk_window_invalidate_region()<br>
 * need to be called as well. And finaly, in order to make all events happen, it<br>
 * is needed to call gdk_window_process_all_updates().
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
extern void gtk_artificial_horizon_redraw (GtkArtificialHorizon * arh)
{
  GtkWidget *widget;
  GdkRegion *region;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_redraw()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  widget = GTK_WIDGET (arh);

  if (!widget->window)
    return;

  region = gdk_drawable_get_clip_region (widget->window);
  /* redraw the window completely by exposing it */
  gdk_window_invalidate_region (widget->window, region, TRUE);
  gdk_window_process_updates (widget->window, TRUE);

  gdk_region_destroy (region);
}


/**
 * @fn extern void gtk_turn_coordinator_set_value (GtkTurnCoordinator * tc, gdouble plane_angle, gdouble ball_val)
 * @brief Public widget's function that allow the main program/user to<br>
 * set the internal value variable of the widget.
 *
 * Here, tree values have to be set:<br>
 * "rotation_angle": double, provide rotation of the widget sphere<br>
 * and external arc - the value is from 0 to 360.<br>
 * "trans_y": double, provide sphere translation - the value is from -70 to 70
 */
extern void gtk_artificial_horizon_set_value (GtkArtificialHorizon * arh, gdouble angle, gdouble y)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_set_value()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  if(!gtk_artificial_horizon_lock_update)
  {
		if ((angle >= 0) && (angle <= 360))
			priv->angle = angle;
		else
			g_warning ("GtkArtificialHorizon : gtk_artificial_horizon_set_value : value out of range");

		if ((y >= -70) && (y <= 70))
			priv->trans_y = y;
		else
			g_warning ("GtkArtificialHorizon : gtk_artificial_horizon_set_value : value out of range");
  }
  return;
}

/**
 * @fn extern GtkWidget *gtk_artificial_horizon_new (void)
 * @brief Special Gtk API function. This function is simply a wrapper<br>
 * for convienience.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
extern GtkWidget *gtk_artificial_horizon_new (void)
{
  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_new()");
  }
  return GTK_WIDGET (gtk_type_new (gtk_artificial_horizon_get_type ()));
}

/**
 * @fn static void gtk_artificial_horizon_draw_static (GtkWidget * arh, cairo_t * cr)
 * @brief Special Gtk API function. This function use the cairo context<br>
 * created before in order to draw scalable graphics.
 *
 * See GObject,Cairo and GTK+ references for more informations:
 * http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_draw_static (GtkWidget * arh, cairo_t * cr)
{
  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_static()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  gtk_artificial_horizon_draw_base (arh,cr);
  gtk_artificial_horizon_draw_screws (arh,cr);
}

/**
 * @fn static void gtk_artificial_horizon_draw_dynamic (GtkWidget * arh, cairo_t * cr)
 * @brief Special Gtk API function. This function use the cairo context<br>
 * created before in order to draw scalable graphics.
 *
 * See GObject,Cairo and GTK+ references for more informations:
 * http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_draw_dynamic (GtkWidget * arh, cairo_t * cr)
{
    GtkArtificialHorizonPrivate *priv;

    if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_dynamic()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON(arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, radius;
  cairo_pattern_t *pat = NULL;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;

  cairo_save(cr);
  cairo_set_line_width (cr, 0.01 * radius);
  cairo_arc (cr, x, y, radius, 0, 2 * M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.blue / 65535, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_clip (cr);        // **** allows hiding that the internal sphere to be 2* bigger than the widget
  cairo_stroke (cr);

  priv->radius = radius;
  priv->x = x;
  priv->y = y;
  gtk_artificial_horizon_draw_internal_sphere (arh,cr);
  cairo_restore(cr);

  gtk_artificial_horizon_draw_external_arc (arh,cr);
  gtk_artificial_horizon_draw_upper_base(arh,cr);
  cairo_pattern_destroy (pat);
}

/**
 * @fn static void gtk_artificial_horizon_draw (GtkWidget * arh, cairo_t * cr)
 * @brief Special Gtk API function. Override the _draw handler of the<br>
 * parent class GtkDrawingArea. This function use the cairo context<br>
 * created before in order to draw scalable graphics.
 *
 * See GObject,Cairo and GTK+ references for more informations:
 * http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_draw_base (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, rec_x0, rec_y0, rec_width, rec_height, rec_degrees;
  double rec_aspect, rec_corner_radius, rec_radius, radius;
  cairo_pattern_t *pat = NULL;

  x = arh->allocation.width / 2;
  y = arh->allocation.height / 2;
  radius = MIN (arh->allocation.width / 2, arh->allocation.height / 2) - 5;

  rec_x0 = x - radius;
  rec_y0 = y - radius;
  rec_width = radius * 2;
  rec_height = radius * 2;
  rec_aspect = 1.0;
  rec_corner_radius = rec_height / 8.0;

  rec_radius = rec_corner_radius / rec_aspect;
  rec_degrees = M_PI / 180.0;

  // artificialhorizon base
  cairo_new_sub_path (cr);
  cairo_arc (cr, rec_x0 + rec_width - rec_radius, rec_y0 + rec_radius,
             rec_radius, -90 * rec_degrees, 0 * rec_degrees);
  cairo_arc (cr, rec_x0 + rec_width - rec_radius, rec_y0 + rec_height - rec_radius,
             rec_radius, 0 * rec_degrees, 90 * rec_degrees);
  cairo_arc (cr, rec_x0 + rec_radius, rec_y0 + rec_height - rec_radius,
             rec_radius, 90 * rec_degrees, 180 * rec_degrees);
  cairo_arc (cr, rec_x0 + rec_radius, rec_y0 + rec_radius, rec_radius, 180 * rec_degrees, 270 * rec_degrees);
  cairo_close_path (cr);

  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_bounderie.red / 65535,
                            (gdouble) priv->bg_color_bounderie.green / 65535,
                            (gdouble) priv->bg_color_bounderie.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_bounderie.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, (gdouble) priv->bg_color_bounderie.red / 65535,
                                       (gdouble) priv->bg_color_bounderie.green / 65535,
                                       (gdouble) priv->bg_color_bounderie.blue / 65535, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x, y, radius, 0, 2 * M_PI);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0., 0., 0.);
  else
    cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x, y, radius - 0.04 * radius, 0, 2 * M_PI);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0.6, 0.5, 0.5);
  else
    cairo_set_source_rgb (cr, 1 - 0.6, 1 - 0.5, 1 - 0.5);
  cairo_stroke (cr);

  radius = radius - 0.1 * radius;
  priv->radius = radius;
  priv->x = x;
  priv->y = y;

  cairo_pattern_destroy (pat);
  return;
}

/**
 * @fn static void gtk_artificial_horizon_draw_grayscale_pattern (GtkWidget * arh, cairo_t * cr)
 * @brief Special Gtk API function. This function use the cairo context<br>
 * created before in order to draw scalable graphics.
 *
 * See GObject,Cairo and GTK+ references for more informations:
 * http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_draw_grayscale_pattern (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_upper_base()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON(arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, radius;
  cairo_pattern_t *pat = NULL;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;

  if ((priv->radial_color) && (!priv->grayscale_color))
  {
    x = priv->x;
    y = priv->y;
    cairo_arc (cr, x, y, radius, 0, 2 * M_PI);
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.blue / 65535, 0.7);
    cairo_pattern_add_color_stop_rgba (pat, 1, (gdouble) priv->bg_radial_color_begin_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.blue / 65535, 0.05);
    cairo_set_source (cr, pat);
    cairo_fill_preserve (cr);
    cairo_stroke (cr);
  }
  cairo_pattern_destroy (pat);
}

/**
 * @fn static void gtk_artificial_horizon_draw_upper_base (GtkWidget * arh, cairo_t * cr)
 * @brief Special Gtk API function. This function use the cairo context<br>
 * created before in order to draw scalable graphics.
 *
 * See GObject,Cairo and GTK+ references for more informations:
 * http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_draw_upper_base (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_upper_base()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON(arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, radius;
  cairo_pattern_t *pat = NULL;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;

  // **** alpha arc
  cairo_arc (cr, x, y, radius - 0.15 * radius, 0, 2 * M_PI);
  pat = cairo_pattern_create_radial (x, y, radius - 0.23 * radius, x, y, radius - 0.15 * radius);
  cairo_pattern_add_color_stop_rgba (pat, 0, 0.3, 0.3, 0.3, 0.1);
  cairo_pattern_add_color_stop_rgba (pat, 1, 0.3, 0.3, 0.3, 0.6);
  cairo_set_source (cr, pat);
  cairo_fill (cr);
  cairo_stroke (cr);

  // **** base arrow
  cairo_new_sub_path (cr);
  cairo_set_line_width (cr, 0.02 * radius);
  cairo_set_source_rgba (cr, 0.3, 0.3, 0.3, 0.15);
  cairo_move_to (cr, x + (radius - 0.205 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.205 * radius) * sin (-M_PI / 2));
  cairo_line_to (cr, x + (radius - 0.325 * radius) * cos (-M_PI / 2 + M_PI / 30),
                 y + (radius - 0.325 * radius) * sin (-M_PI / 2 + M_PI / 30));
  cairo_line_to (cr, x + (radius - 0.325 * radius) * cos (-M_PI / 2 - M_PI / 30),
                 y + (radius - 0.325 * radius) * sin (-M_PI / 2 - M_PI / 30));
  cairo_line_to (cr, x + (radius - 0.205 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.205 * radius) * sin (-M_PI / 2));
  cairo_close_path (cr);
  cairo_stroke (cr);

  cairo_new_sub_path (cr);
  cairo_set_line_width (cr, 0.02 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 1, 0.65, 0.);
  else
    cairo_set_source_rgb (cr, 0, 0, 0);
  cairo_move_to (cr, x + (radius - 0.18 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.18 * radius) * sin (-M_PI / 2));
  cairo_line_to (cr, x + (radius - 0.3 * radius) * cos (-M_PI / 2 + M_PI / 30),
                 y + (radius - 0.3 * radius) * sin (-M_PI / 2 + M_PI / 30));
  cairo_line_to (cr, x + (radius - 0.3 * radius) * cos (-M_PI / 2 - M_PI / 30),
                 y + (radius - 0.3 * radius) * sin (-M_PI / 2 - M_PI / 30));
  cairo_line_to (cr, x + (radius - 0.18 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.18 * radius) * sin (-M_PI / 2));
  cairo_close_path (cr);
  cairo_stroke (cr);

  // **** base quart arc
  cairo_arc (cr, x, y, radius + 0.009 * radius, M_PI / 5, 4 * M_PI / 5);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.blue / 65535, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill (cr);
  cairo_stroke (cr);

  cairo_new_sub_path (cr);
  cairo_set_line_width (cr, 0.02 * radius);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                            (gdouble) priv->bg_color_artificialhorizon.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_artificialhorizon.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, (gdouble) priv->bg_color_artificialhorizon.red / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.green / 65535,
                                       (gdouble) priv->bg_color_artificialhorizon.blue / 65535, 1);
    cairo_set_source (cr, pat);
  }
  cairo_move_to (cr, x - 0.3 * radius, y + 0.60 * radius);
  cairo_line_to (cr, x - 0.2 * radius, y + 0.35 * radius);
  cairo_line_to (cr, x - 0.05 * radius, y + 0.35 * radius);
  cairo_line_to (cr, x - 0.05 * radius, y + 0.25 * radius);
  cairo_line_to (cr, x - 0.015 * radius, y + 0.15 * radius);
  cairo_line_to (cr, x - 0.015 * radius, y);
  cairo_line_to (cr, x + 0.015 * radius, y);
  cairo_line_to (cr, x + 0.015 * radius, y + 0.15 * radius);
  cairo_line_to (cr, x + 0.05 * radius, y + 0.25 * radius);
  cairo_line_to (cr, x + 0.05 * radius, y + 0.35 * radius);
  cairo_line_to (cr, x + 0.2 * radius, y + 0.35 * radius);
  cairo_line_to (cr, x + 0.3 * radius, y + 0.60 * radius);
  cairo_fill (cr);
  cairo_close_path (cr);
  cairo_stroke (cr);

  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0, 0, 0);
  else
    cairo_set_source_rgb (cr, 1, 1, 1);
  cairo_set_line_width (cr, 0.06 * radius);
  cairo_move_to (cr, x - 0.61 * radius, y);
  cairo_line_to (cr, x - 0.2 * radius, y);
  cairo_line_to (cr, x - 0.1 * radius, y + 0.1 * radius);
  cairo_line_to (cr, x, y);
  cairo_line_to (cr, x + 0.1 * radius, y + 0.1 * radius);
  cairo_line_to (cr, x + 0.2 * radius, y);
  cairo_line_to (cr, x + 0.61 * radius, y);
  cairo_stroke (cr);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 1, 0.65, 0.);
  else
    cairo_set_source_rgb (cr, 0, 0, 0);
  cairo_set_line_width (cr, 0.04 * radius);
  cairo_move_to (cr, x - 0.6 * radius, y);
  cairo_line_to (cr, x - 0.2 * radius, y);
  cairo_line_to (cr, x - 0.1 * radius, y + 0.1 * radius);
  cairo_line_to (cr, x, y);
  cairo_line_to (cr, x + 0.1 * radius, y + 0.1 * radius);
  cairo_line_to (cr, x + 0.2 * radius, y);
  cairo_line_to (cr, x + 0.6 * radius, y);
  cairo_stroke (cr);
  cairo_pattern_destroy (pat);
}

/**
 * @fn static void gtk_artificial_horizon_draw_screws (GtkWidget * arh, cairo_t * cr)
 * @brief Private widget's function that draw the widget's screws using cairo.
 */
static void gtk_artificial_horizon_draw_screws (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  cairo_pattern_t *pat = NULL;
  double x, y, radius;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;
  radius = radius + 0.12 * radius;

  // **** top left screw
  cairo_arc (cr, x - 0.82 * radius, y - 0.82 * radius, 0.1 * radius, 0, 2 * M_PI);
  pat = cairo_pattern_create_radial (x - 0.82 * radius, y - 0.82 * radius, 0.07 * radius,
                                     x - 0.82 * radius, y - 0.82 * radius, 0.1 * radius);
  cairo_pattern_add_color_stop_rgba (pat, 0, 0, 0, 0, 0.7);
  cairo_pattern_add_color_stop_rgba (pat, 1, 0, 0, 0, 0.1);
  cairo_set_source (cr, pat);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x - 0.82 * radius, y - 0.82 * radius, 0.07 * radius, 0, 2 * M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_bounderie.red / 65535,
                            (gdouble) priv->bg_color_bounderie.green / 65535,
                            (gdouble) priv->bg_color_bounderie.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_bounderie.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, 0.15, 0.15, 0.15, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.02 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0., 0., 0.);
  else
    cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_move_to (cr, x - 0.88 * radius, y - 0.82 * radius);
  cairo_line_to (cr, x - 0.76 * radius, y - 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.82 * radius, y - 0.88 * radius);
  cairo_line_to (cr, x - 0.82 * radius, y - 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_set_line_width (cr, 0.01 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0.1, 0.1, 0.1);
  else
    cairo_set_source_rgb (cr, 0.9, 0.9, 0.9);
  cairo_move_to (cr, x - 0.88 * radius, y - 0.82 * radius);
  cairo_line_to (cr, x - 0.76 * radius, y - 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.82 * radius, y - 0.88 * radius);
  cairo_line_to (cr, x - 0.82 * radius, y - 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  // **** top right screw
  cairo_arc (cr, x + 0.82 * radius, y - 0.82 * radius, 0.1 * radius, 0, 2 * M_PI);
  pat = cairo_pattern_create_radial (x + 0.82 * radius, y - 0.82 * radius, 0.07 * radius,
                                     x + 0.82 * radius, y - 0.82 * radius, 0.1 * radius);
  cairo_pattern_add_color_stop_rgba (pat, 0, 0, 0, 0, 0.7);
  cairo_pattern_add_color_stop_rgba (pat, 1, 0, 0, 0, 0.1);
  cairo_set_source (cr, pat);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x + 0.82 * radius, y - 0.82 * radius, 0.07 * radius, 0, 2 * M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_bounderie.red / 65535,
                            (gdouble) priv->bg_color_bounderie.green / 65535,
                            (gdouble) priv->bg_color_bounderie.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_bounderie.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, 0.15, 0.15, 0.15, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.02 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0., 0., 0.);
  else
    cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_move_to (cr, x + 0.88 * radius, y - 0.82 * radius);
  cairo_line_to (cr, x + 0.76 * radius, y - 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.82 * radius, y - 0.88 * radius);
  cairo_line_to (cr, x + 0.82 * radius, y - 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_set_line_width (cr, 0.01 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0.1, 0.1, 0.1);
  else
    cairo_set_source_rgb (cr, 0.9, 0.9, 0.9);
  cairo_move_to (cr, x + 0.88 * radius, y - 0.82 * radius);
  cairo_line_to (cr, x + 0.76 * radius, y - 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.82 * radius, y - 0.88 * radius);
  cairo_line_to (cr, x + 0.82 * radius, y - 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  // **** bottom left screw
  cairo_arc (cr, x - 0.82 * radius, y + 0.82 * radius, 0.1 * radius, 0, 2 * M_PI);
  pat = cairo_pattern_create_radial (x - 0.82 * radius, y + 0.82 * radius, 0.07 * radius,
                                     x - 0.82 * radius, y + 0.82 * radius, 0.1 * radius);
  cairo_pattern_add_color_stop_rgba (pat, 0, 0, 0, 0, 0.7);
  cairo_pattern_add_color_stop_rgba (pat, 1, 0, 0, 0, 0.1);
  cairo_set_source (cr, pat);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x - 0.82 * radius, y + 0.82 * radius, 0.07 * radius, 0, 2 * M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_bounderie.red / 65535,
                            (gdouble) priv->bg_color_bounderie.green / 65535,
                            (gdouble) priv->bg_color_bounderie.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_bounderie.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, 0.15, 0.15, 0.15, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.02 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0., 0., 0.);
  else
    cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_move_to (cr, x - 0.88 * radius, y + 0.82 * radius);
  cairo_line_to (cr, x - 0.76 * radius, y + 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.82 * radius, y + 0.88 * radius);
  cairo_line_to (cr, x - 0.82 * radius, y + 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_set_line_width (cr, 0.01 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0.1, 0.1, 0.1);
  else
    cairo_set_source_rgb (cr, 0.9, 0.9, 0.9);
  cairo_move_to (cr, x - 0.88 * radius, y + 0.82 * radius);
  cairo_line_to (cr, x - 0.76 * radius, y + 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.82 * radius, y + 0.88 * radius);
  cairo_line_to (cr, x - 0.82 * radius, y + 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  // **** bottom right screw
  cairo_arc (cr, x + 0.82 * radius, y + 0.82 * radius, 0.1 * radius, 0, 2 * M_PI);
  pat = cairo_pattern_create_radial (x + 0.82 * radius, y + 0.82 * radius, 0.07 * radius,
                                     x + 0.82 * radius, y + 0.82 * radius, 0.1 * radius);
  cairo_pattern_add_color_stop_rgba (pat, 0, 0, 0, 0, 0.7);
  cairo_pattern_add_color_stop_rgba (pat, 1, 0, 0, 0, 0.1);
  cairo_set_source (cr, pat);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x + 0.82 * radius, y + 0.82 * radius, 0.07 * radius, 0, 2 * M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_bounderie.red / 65535,
                            (gdouble) priv->bg_color_bounderie.green / 65535,
                            (gdouble) priv->bg_color_bounderie.blue / 65535);
    else
      cairo_set_source_rgb (cr, (gdouble) priv->bg_color_inv.red / 65535,
                            (gdouble) priv->bg_color_inv.green / 65535, (gdouble) priv->bg_color_inv.blue / 65535);
  }
  else
  {
    pat = cairo_pattern_create_radial (x - 0.392 * radius, y - 0.967 * radius, 0.167 * radius,
                                       x - 0.477 * radius, y - 0.967 * radius, 0.836 * radius);
    cairo_pattern_add_color_stop_rgba (pat, 0, (gdouble) priv->bg_radial_color_begin_bounderie.red / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.green / 65535,
                                       (gdouble) priv->bg_radial_color_begin_bounderie.blue / 65535, 1);
    cairo_pattern_add_color_stop_rgba (pat, 1, 0.15, 0.15, 0.15, 1);
    cairo_set_source (cr, pat);
  }
  cairo_fill_preserve (cr);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.02 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0., 0., 0.);
  else
    cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_move_to (cr, x + 0.88 * radius, y + 0.82 * radius);
  cairo_line_to (cr, x + 0.76 * radius, y + 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.82 * radius, y + 0.88 * radius);
  cairo_line_to (cr, x + 0.82 * radius, y + 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_set_line_width (cr, 0.01 * radius);
  if (!priv->grayscale_color)
    cairo_set_source_rgb (cr, 0.1, 0.1, 0.1);
  else
    cairo_set_source_rgb (cr, 0.9, 0.9, 0.9);
  cairo_move_to (cr, x + 0.88 * radius, y + 0.82 * radius);
  cairo_line_to (cr, x + 0.76 * radius, y + 0.82 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.82 * radius, y + 0.88 * radius);
  cairo_line_to (cr, x + 0.82 * radius, y + 0.76 * radius);
  cairo_fill_preserve (cr);
  cairo_stroke (cr);
  cairo_pattern_destroy (pat);
  return;
}

/**
 * @fn static void gtk_artificial_horizon_draw_internal_sphere (GtkWidget * arh, cairo_t * cr)
 * @brief Private widget's function that draw the widget's internal sphere using cairo.
 */
static void gtk_artificial_horizon_draw_internal_sphere (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_internal_sphere()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, radius;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;

  cairo_save (cr);
  cairo_translate (cr, x, y);
  x = 0;
  y = (priv->trans_y * 0.134 * radius) / 10;    //priv->trans_y;
  cairo_rotate (cr, DEG2RAD (priv->angle));

  // **** internal sphere
  cairo_arc (cr, x, y, 2 * radius, M_PI, 0);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, 0.117, 0.564, 1.);
    else
      cairo_set_source_rgb (cr, 0.8, 0.8, 0.8);
  }
  else
  {
    cairo_set_source_rgb (cr, 0.117, 0.564, 1.);
  }
  cairo_fill (cr);
  cairo_stroke (cr);

  cairo_arc (cr, x, y, 2 * radius, 0, M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, 0.651, 0.435, 0.098);
    else
      cairo_set_source_rgb (cr, 0.2, 0.2, 0.2);
  }
  else
  {
    cairo_set_source_rgb (cr, 0.651, 0.435, 0.098);
  }
  cairo_fill (cr);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.02 * radius);
  cairo_move_to (cr, x - radius, y);
  cairo_line_to (cr, x + radius, y);
  cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_stroke (cr);

  // **** horizontal line (pitch)
  cairo_move_to (cr, x - 0.4 * radius, y - 0.4 * radius);
  cairo_line_to (cr, x + 0.4 * radius, y - 0.4 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.3 * radius, y - 0.268 * radius);
  cairo_line_to (cr, x + 0.3 * radius, y - 0.268 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.2 * radius, y - 0.134 * radius);
  cairo_line_to (cr, x + 0.2 * radius, y - 0.134 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y - 0.4 * radius + 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y - 0.4 * radius + 0.067 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y - 0.268 * radius + 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y - 0.268 * radius + 0.067 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y - 0.134 * radius + 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y - 0.134 * radius + 0.067 * radius);
  cairo_stroke (cr);

  cairo_move_to (cr, x - 0.4 * radius, y + 0.4 * radius);
  cairo_line_to (cr, x + 0.4 * radius, y + 0.4 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.3 * radius, y + 0.268 * radius);
  cairo_line_to (cr, x + 0.3 * radius, y + 0.268 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.2 * radius, y + 0.134 * radius);
  cairo_line_to (cr, x + 0.2 * radius, y + 0.134 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y + 0.4 * radius - 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y + 0.4 * radius - 0.067 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y + 0.268 * radius - 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y + 0.268 * radius - 0.067 * radius);
  cairo_stroke (cr);
  cairo_move_to (cr, x - 0.1 * radius, y + 0.134 * radius - 0.067 * radius);
  cairo_line_to (cr, x + 0.1 * radius, y + 0.134 * radius - 0.067 * radius);
  cairo_stroke (cr);

  // **** 10 drawing
  cairo_select_font_face (cr, "Sans", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
  cairo_set_font_size (cr, 0.1 * radius);
  cairo_move_to (cr, x - 0.35 * radius, y - 0.1 * radius);
  cairo_show_text (cr, "10");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.21 * radius, y - 0.1 * radius);
  cairo_show_text (cr, "10");
  cairo_stroke (cr);

  cairo_move_to (cr, x - 0.35 * radius, y + 0.17 * radius);
  cairo_show_text (cr, "10");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.21 * radius, y + 0.17 * radius);
  cairo_show_text (cr, "10");
  cairo_stroke (cr);

  // **** 20 drawing
  cairo_move_to (cr, x - 0.45 * radius, y - 0.234 * radius);
  cairo_show_text (cr, "20");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.31 * radius, y - 0.234 * radius);
  cairo_show_text (cr, "20");
  cairo_stroke (cr);

  cairo_move_to (cr, x - 0.45 * radius, y + 0.302 * radius);
  cairo_show_text (cr, "20");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.31 * radius, y + 0.302 * radius);
  cairo_show_text (cr, "20");
  cairo_stroke (cr);

  // **** 30 drawing
  cairo_move_to (cr, x - 0.55 * radius, y - 0.368 * radius);
  cairo_show_text (cr, "30");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.41 * radius, y - 0.368 * radius);
  cairo_show_text (cr, "30");
  cairo_stroke (cr);

  cairo_move_to (cr, x - 0.55 * radius, y + 0.434 * radius);
  cairo_show_text (cr, "30");
  cairo_stroke (cr);
  cairo_move_to (cr, x + 0.41 * radius, y + 0.434 * radius);
  cairo_show_text (cr, "30");
  cairo_stroke (cr);
  cairo_restore (cr);
  return;
}

/**
 * @fn static void gtk_artificial_horizon_draw_external_arc (GtkWidget * arh, cairo_t * cr)
 * @brief Private widget's function that draw the widget's external arc using cairo.
 */
static void gtk_artificial_horizon_draw_external_arc (GtkWidget * arh, cairo_t * cr)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_draw_external_arc()");
  }
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);

  double x, y, radius;
  radius = priv->radius;
  x = priv->x;
  y = priv->y;

  cairo_save (cr);
  cairo_translate (cr, x, y);
  x = 0;
  y = 0;
  cairo_rotate (cr, DEG2RAD (priv->angle));

  // **** external demi arc sky
  cairo_set_line_width (cr, 0.15 * radius);
  cairo_arc (cr, x, y, radius - 0.075 * radius, M_PI, 0);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, 0.117, 0.564, 1.);
    else
      cairo_set_source_rgb (cr, 0.8, 0.8, 0.8);
  }
  else
  {
    cairo_set_source_rgb (cr, 0.117, 0.564, 1.);
  }
  cairo_stroke (cr);

  // **** external demi arc ground
  cairo_arc (cr, x, y, radius - 0.075 * radius, 0, M_PI);
  if (((priv->radial_color) && (priv->grayscale_color)) || ((!priv->radial_color) && (priv->grayscale_color))
      || ((!priv->radial_color) && (!priv->grayscale_color)))
  {
    if (!priv->grayscale_color)
      cairo_set_source_rgb (cr, 0.651, 0.435, 0.098);
    else
      cairo_set_source_rgb (cr, 0.2, 0.2, 0.2);
  }
  else
  {
    cairo_set_source_rgb (cr, 0.651, 0.435, 0.098);
  }
  cairo_stroke (cr);

  // **** external arc alpha composante
  cairo_arc (cr, x, y, radius - 0.075 * radius, 0, 2 * M_PI);
  cairo_set_source_rgba (cr, 0.3, 0.3, 0.3, 0.3);
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.04 * radius);
  cairo_move_to (cr, x - radius, y);
  cairo_line_to (cr, x - radius + 0.15 * radius, y);
  cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_stroke (cr);
  cairo_set_line_width (cr, 0.04 * radius);
  cairo_move_to (cr, x + radius, y);
  cairo_line_to (cr, x + radius - 0.15 * radius, y);
  cairo_set_source_rgb (cr, 1., 1., 1.);
  cairo_stroke (cr);

  // **** external arc tips
  cairo_set_line_width (cr, 0.02 * radius);
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-M_PI / 6),
                 y + (radius - 0.15 * radius) * sin (-M_PI / 6));
  cairo_line_to (cr, x + (radius - 0.04 * radius) * cos (-M_PI / 6),
                 y + (radius - 0.04 * radius) * sin (-M_PI / 6));
  cairo_stroke (cr);

  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-2 * M_PI / 6),
                 y + (radius - 0.15 * radius) * sin (-2 * M_PI / 6));
  cairo_line_to (cr, x + (radius - 0.04 * radius) * cos (-2 * M_PI / 6),
                 y + (radius - 0.04 * radius) * sin (-2 * M_PI / 6));
  cairo_stroke (cr);

  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-4 * M_PI / 6),
                 y + (radius - 0.15 * radius) * sin (-4 * M_PI / 6));
  cairo_line_to (cr, x + (radius - 0.04 * radius) * cos (-4 * M_PI / 6),
                 y + (radius - 0.04 * radius) * sin (-4 * M_PI / 6));
  cairo_stroke (cr);

  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-5 * M_PI / 6),
                 y + (radius - 0.15 * radius) * sin (-5 * M_PI / 6));
  cairo_line_to (cr, x + (radius - 0.04 * radius) * cos (-5 * M_PI / 6),
                 y + (radius - 0.04 * radius) * sin (-5 * M_PI / 6));
  cairo_stroke (cr);

  cairo_set_line_width (cr, 0.015 * radius);
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-7 * M_PI / 18),
                 y + (radius - 0.15 * radius) * sin (-7 * M_PI / 18));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-7 * M_PI / 18),
                 y + (radius - 0.07 * radius) * sin (-7 * M_PI / 18));
  cairo_stroke (cr);
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-8 * M_PI / 18),
                 y + (radius - 0.15 * radius) * sin (-8 * M_PI / 18));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-8 * M_PI / 18),
                 y + (radius - 0.07 * radius) * sin (-8 * M_PI / 18));
  cairo_stroke (cr);
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-10 * M_PI / 18),
                 y + (radius - 0.15 * radius) * sin (-10 * M_PI / 18));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-10 * M_PI / 18),
                 y + (radius - 0.07 * radius) * sin (-10 * M_PI / 18));
  cairo_stroke (cr);
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-11 * M_PI / 18),
                 y + (radius - 0.15 * radius) * sin (-11 * M_PI / 18));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-11 * M_PI / 18),
                 y + (radius - 0.07 * radius) * sin (-11 * M_PI / 18));
  cairo_stroke (cr);

  // **** external arc arrow
  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-3 * M_PI / 12),
                 y + (radius - 0.15 * radius) * sin (-3 * M_PI / 12));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-3 * M_PI / 12 + M_PI / 45),
                 y + (radius - 0.07 * radius) * sin (-3 * M_PI / 12 + M_PI / 45));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-3 * M_PI / 12 - M_PI / 45),
                 y + (radius - 0.07 * radius) * sin (-3 * M_PI / 12 - M_PI / 45));
  cairo_line_to (cr, x + (radius - 0.15 * radius) * cos (-3 * M_PI / 12),
                 y + (radius - 0.15 * radius) * sin (-3 * M_PI / 12));
  cairo_fill (cr);
  cairo_stroke (cr);

  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-9 * M_PI / 12),
                 y + (radius - 0.15 * radius) * sin (-9 * M_PI / 12));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-9 * M_PI / 12 + M_PI / 45),
                 y + (radius - 0.07 * radius) * sin (-9 * M_PI / 12 + M_PI / 45));
  cairo_line_to (cr, x + (radius - 0.07 * radius) * cos (-9 * M_PI / 12 - M_PI / 45),
                 y + (radius - 0.07 * radius) * sin (-9 * M_PI / 12 - M_PI / 45));
  cairo_line_to (cr, x + (radius - 0.15 * radius) * cos (-9 * M_PI / 12),
                 y + (radius - 0.15 * radius) * sin (-9 * M_PI / 12));
  cairo_fill (cr);
  cairo_stroke (cr);

  cairo_move_to (cr, x + (radius - 0.15 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.15 * radius) * sin (-M_PI / 2));
  cairo_line_to (cr, x + radius * cos (-M_PI / 2 + M_PI / 30), y + radius * sin (-M_PI / 2 + M_PI / 30));
  cairo_line_to (cr, x + radius * cos (-M_PI / 2 - M_PI / 30), y + radius * sin (-M_PI / 2 - M_PI / 30));
  cairo_line_to (cr, x + (radius - 0.15 * radius) * cos (-M_PI / 2),
                 y + (radius - 0.15 * radius) * sin (-M_PI / 2));
  cairo_fill (cr);
  cairo_stroke (cr);
  cairo_restore (cr);
  return;
}

/**
 * @fn static gboolean gtk_artificial_horizon_button_press_event (GtkWidget * widget, GdkEventButton * ev)
 * @brief Special Gtk API function. Override the _button_press_event<br>
 * handler. Perform mouse button press events.
 *
 * Here, the mouse events are not used for the widget (maybe<br>
 * in future released) but to allow the user to enable/disable<br>
 * the debug messages.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static gboolean gtk_artificial_horizon_button_press_event (GtkWidget * widget, GdkEventButton * ev)
{
  GtkArtificialHorizonPrivate *priv;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_button_press_event_cb()");
  }
  g_return_val_if_fail (IS_GTK_ARTIFICIAL_HORIZON (widget), FALSE);

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (widget);

  if ((ev->type & GDK_BUTTON_PRESS) && (ev->button == 2) && priv->b_mouse_onoff)
  {
    gtk_artificial_horizon_debug = gtk_artificial_horizon_debug ? FALSE : TRUE;
    return TRUE;
  }
  if ((ev->type & GDK_BUTTON_PRESS) && (ev->button == 1) && priv->b_mouse_onoff)
  {
    gtk_artificial_horizon_lock_update = gtk_artificial_horizon_lock_update ? FALSE : TRUE;
    return TRUE;
  }
  if ((ev->type & GDK_BUTTON_PRESS) && (ev->button == 3))
  {
    priv->b_mouse_onoff = priv->b_mouse_onoff ? FALSE : TRUE;
    return TRUE;
  }

  return FALSE;
}

/**
 * @fn static void gtk_artificial_horizon_destroy (GtkObject * object)
 * @brief Special Gtk API function. Override the _destroy handler.<br>
 * Allow the destruction of all widget's pointer.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_destroy (GtkObject * object)
{
  GtkArtificialHorizonPrivate *priv = NULL;
  GtkWidget *widget = NULL;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_destroy(enter)");
  }

  g_return_if_fail (object != NULL);

  widget = GTK_WIDGET (object);

  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (widget));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (widget);
  g_return_if_fail (priv != NULL);

  if (priv->static_surface)
  {
    priv->static_surface=NULL;
    priv->dynamic_surface=NULL;
    priv->g_pat_surface=NULL;

    if (GTK_OBJECT_CLASS (gtk_artificial_horizon_parent_class)->destroy != NULL)
    {
      (*GTK_OBJECT_CLASS (gtk_artificial_horizon_parent_class)->destroy) (object);
    }
  }
  if (gtk_artificial_horizon_debug)
  {
    g_debug ("gtk_artificial_horizon_destroy(exit)");
  }
  return;
}

/**
 * @fn static void gtk_artificial_horizon_set_property (GObject * object, guint prop_id, const GValue * value, GParamSpec * pspec)
 * @brief Special Gtk API function. Override the _set_property handler <br>
 * in order to set the object parameters.
 *
 * See GObject and GTK+ references for
 * more informations: http://library.gnome.org/devel/references.html.en
 */
static void gtk_artificial_horizon_set_property (GObject * object, guint prop_id, const GValue * value,
                                                 GParamSpec * pspec)
{
  GtkArtificialHorizonPrivate *priv = NULL;
  GtkArtificialHorizon *arh = NULL;

  if (gtk_artificial_horizon_debug)
  {
    g_debug ("===> gtk_artificial_horizon_set_property()");
  }
  g_return_if_fail (object != NULL);

  arh = GTK_ARTIFICIAL_HORIZON (object);
  g_return_if_fail (IS_GTK_ARTIFICIAL_HORIZON (arh));

  priv = GTK_ARTIFICIAL_HORIZON_GET_PRIVATE (arh);
  g_return_if_fail (priv != NULL);

  switch (prop_id)
  {
    case PROP_GRAYSCALE_COLOR:
      priv->grayscale_color = g_value_get_boolean (value);
      break;
    case PROP_RADIAL_COLOR:
      priv->radial_color = g_value_get_boolean (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
      break;
  }
  return;
}
