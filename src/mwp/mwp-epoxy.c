/*
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * (c) Jonathan Hudson <jh+mwptools@daria.co.uk>
 */

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
