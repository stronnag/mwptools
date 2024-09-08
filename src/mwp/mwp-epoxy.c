#include <stdio.h>
#include <epoxy/gl.h>
#include <epoxy/glx.h>

extern void mwp_log_message (const char* format,...);

int epoxy_glinfo() {
  const GLubyte *renderer = glGetString( GL_RENDERER );
  const GLubyte *vendor = glGetString( GL_VENDOR );
  const GLubyte *version = glGetString( GL_VERSION );
  /*
        const GLubyte *glslVersion = glGetString( GL_SHADING_LANGUAGE_VERSION );
        GLint major, minor;
        glGetIntegerv(GL_MAJOR_VERSION, &major);
        glGetIntegerv(GL_MINOR_VERSION, &minor);
        printf("GL Vendor : %s\n", vendor);
        printf("GL Renderer : %s\n", renderer);
        printf("GL Version (string) : %s\n", version);
        printf("GL Version (integer) : %d.%d\n", major, minor);
        printf("GLSL Version : %s\n", glslVersion);
	*/
  if(renderer != NULL && version != NULL) {
    mwp_log_message("GL: %s %s\n", renderer, version);
    return 0;
  }
  return 1;
}
