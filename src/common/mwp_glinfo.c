#include <stdio.h>
#include <glib.h>
#include <gmodule.h>
#include <GL/gl.h>

typedef char*(*glfunc_t)(int);

void get_glinfo(char **vendp, char **rendp)
{
     GModule *handle = NULL;
     gchar * modname = NULL;
     glfunc_t glfunc;
     modname = g_module_build_path(NULL, "libGL");
     if(modname) {
	  handle = g_module_open(modname, G_MODULE_BIND_LAZY);
	  if (handle) {
	       if(g_module_symbol(handle, "glGetString", (gpointer *)&glfunc)) {
		    char *renderer = (*glfunc)(GL_RENDERER);
		    char *vendor = (*glfunc)(GL_VENDOR);
		    *vendp = vendor;
		    *rendp = renderer;
	       }
	  }
     }
     return;
}
