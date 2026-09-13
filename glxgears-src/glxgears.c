/*
 * glxgears - 3D gear wheels demo and benchmark for FreeLinX
 *
 * Based on Brian Paul's classic 3D gears demo and TinyGL software rasterizer.
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/Xatom.h>
#include <X11/keysym.h>
#include <GL/gl.h>
#include <GL/glx.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static GLfloat view_rotx = 20.0f, view_roty = 30.0f, view_rotz = 0.0f;
static GLint gear1, gear2, gear3;
static GLfloat angle = 0.0f;

static Display *dpy = NULL;
static Window win = 0;
static GLXContext ctx = NULL;
static Atom wm_delete_window;

/* Draw a gear wheel */
static void gear(GLfloat inner_radius, GLfloat outer_radius, GLfloat width,
                 GLint teeth, GLfloat tooth_depth)
{
    GLint i;
    GLfloat r0, r1, r2;
    GLfloat angle_step, da;
    GLfloat u, v, len;

    r0 = inner_radius;
    r1 = outer_radius - tooth_depth / 2.0f;
    r2 = outer_radius + tooth_depth / 2.0f;

    da = 2.0f * (GLfloat)M_PI / (GLfloat)teeth / 4.0f;

    glShadeModel(GL_FLAT);
    glNormal3f(0.0f, 0.0f, 1.0f);

    /* draw front face */
    glBegin(GL_QUAD_STRIP);
    for (i = 0; i <= teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;
        glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), width * 0.5f);
        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), width * 0.5f);
        if (i < teeth) {
            glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), width * 0.5f);
            glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), width * 0.5f);
        }
    }
    glEnd();

    /* draw front sides of teeth */
    glBegin(GL_QUADS);
    da = 2.0f * (GLfloat)M_PI / (GLfloat)teeth / 4.0f;
    for (i = 0; i < teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;
        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + da), r2 * sinf(angle_step + da), width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + 2.0f * da), r2 * sinf(angle_step + 2.0f * da), width * 0.5f);
        glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), width * 0.5f);
    }
    glEnd();

    glNormal3f(0.0f, 0.0f, -1.0f);

    /* draw back face */
    glBegin(GL_QUAD_STRIP);
    for (i = 0; i <= teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;
        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), -width * 0.5f);
        glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), -width * 0.5f);
        if (i < teeth) {
            glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), -width * 0.5f);
            glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), -width * 0.5f);
        }
    }
    glEnd();

    /* draw back sides of teeth */
    glBegin(GL_QUADS);
    for (i = 0; i < teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;
        glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), -width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + 2.0f * da), r2 * sinf(angle_step + 2.0f * da), -width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + da), r2 * sinf(angle_step + da), -width * 0.5f);
        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), -width * 0.5f);
    }
    glEnd();

    /* draw outward faces of teeth */
    glBegin(GL_QUAD_STRIP);
    for (i = 0; i < teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;

        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), width * 0.5f);
        glVertex3f(r1 * cosf(angle_step), r1 * sinf(angle_step), -width * 0.5f);
        u = r2 * cosf(angle_step + da) - r1 * cosf(angle_step);
        v = r2 * sinf(angle_step + da) - r1 * sinf(angle_step);
        len = sqrtf(u * u + v * v);
        u /= len;
        v /= len;
        glNormal3f(v, -u, 0.0f);
        glVertex3f(r2 * cosf(angle_step + da), r2 * sinf(angle_step + da), width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + da), r2 * sinf(angle_step + da), -width * 0.5f);
        glNormal3f(cosf(angle_step), sinf(angle_step), 0.0f);
        glVertex3f(r2 * cosf(angle_step + 2.0f * da), r2 * sinf(angle_step + 2.0f * da), width * 0.5f);
        glVertex3f(r2 * cosf(angle_step + 2.0f * da), r2 * sinf(angle_step + 2.0f * da), -width * 0.5f);
        u = r1 * cosf(angle_step + 3.0f * da) - r2 * cosf(angle_step + 2.0f * da);
        v = r1 * sinf(angle_step + 3.0f * da) - r2 * sinf(angle_step + 2.0f * da);
        glNormal3f(v, -u, 0.0f);
        glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), width * 0.5f);
        glVertex3f(r1 * cosf(angle_step + 3.0f * da), r1 * sinf(angle_step + 3.0f * da), -width * 0.5f);
        glNormal3f(cosf(angle_step), sinf(angle_step), 0.0f);
    }
    glVertex3f(r1 * cosf(0), r1 * sinf(0), width * 0.5f);
    glVertex3f(r1 * cosf(0), r1 * sinf(0), -width * 0.5f);
    glEnd();

    glShadeModel(GL_SMOOTH);

    /* draw inside radius cylinder */
    glBegin(GL_QUAD_STRIP);
    for (i = 0; i <= teeth; i++) {
        angle_step = i * 2.0f * (GLfloat)M_PI / (GLfloat)teeth;
        glNormal3f(-cosf(angle_step), -sinf(angle_step), 0.0f);
        glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), -width * 0.5f);
        glVertex3f(r0 * cosf(angle_step), r0 * sinf(angle_step), width * 0.5f);
    }
    glEnd();
}

static void draw(void)
{
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glPushMatrix();
    glRotatef(view_rotx, 1.0f, 0.0f, 0.0f);
    glRotatef(view_roty, 0.0f, 1.0f, 0.0f);
    glRotatef(view_rotz, 0.0f, 0.0f, 1.0f);

    /* Gear 1 - Red */
    glPushMatrix();
    glTranslatef(-3.0f, -2.0f, 0.0f);
    glRotatef(angle, 0.0f, 0.0f, 1.0f);
    glCallList(gear1);
    glPopMatrix();

    /* Gear 2 - Green */
    glPushMatrix();
    glTranslatef(3.1f, -2.0f, 0.0f);
    glRotatef(-2.0f * angle - 9.0f, 0.0f, 0.0f, 1.0f);
    glCallList(gear2);
    glPopMatrix();

    /* Gear 3 - Blue */
    glPushMatrix();
    glTranslatef(-3.1f, 4.2f, 0.0f);
    glRotatef(-2.0f * angle - 25.0f, 0.0f, 0.0f, 1.0f);
    glCallList(gear3);
    glPopMatrix();

    glPopMatrix();
}

static void reshape(int width, int height)
{
    GLfloat h = (GLfloat)height / (GLfloat)width;
    glViewport(0, 0, (GLint)width, (GLint)height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glFrustum(-1.0, 1.0, -h, h, 5.0, 60.0);
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();
    glTranslatef(0.0f, 0.0f, -40.0f);
}

static void init_scene(void)
{
    static GLfloat pos[4]   = {5.0f, 5.0f, 10.0f, 0.0f};
    static GLfloat red[4]   = {0.8f, 0.1f, 0.0f, 1.0f};
    static GLfloat green[4] = {0.0f, 0.8f, 0.2f, 1.0f};
    static GLfloat blue[4]  = {0.2f, 0.2f, 1.0f, 1.0f};

    glLightfv(GL_LIGHT0, GL_POSITION, pos);
    glEnable(GL_CULL_FACE);
    glEnable(GL_LIGHTING);
    glEnable(GL_LIGHT0);
    glEnable(GL_DEPTH_TEST);

    /* Gear 1 */
    gear1 = glGenLists(1);
    glNewList(gear1, GL_COMPILE);
    glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, red);
    gear(1.0f, 4.0f, 1.0f, 20, 0.7f);
    glEndList();

    /* Gear 2 */
    gear2 = glGenLists(1);
    glNewList(gear2, GL_COMPILE);
    glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, green);
    gear(0.5f, 2.0f, 2.0f, 10, 0.7f);
    glEndList();

    /* Gear 3 */
    gear3 = glGenLists(1);
    glNewList(gear3, GL_COMPILE);
    glMaterialfv(GL_FRONT, GL_AMBIENT_AND_DIFFUSE, blue);
    gear(1.3f, 2.0f, 0.5f, 10, 0.7f);
    glEndList();

    glEnable(GL_NORMALIZE);
}

static double get_time(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec * 1e-9;
}

int main(int argc, char **argv)
{
    int win_w = 300;
    int win_h = 300;
    int info = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-info") == 0 || strcmp(argv[i], "--info") == 0)
            info = 1;
        else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
            printf("Usage: glxgears [-info]\n");
            return 0;
        }
    }

    dpy = XOpenDisplay(NULL);
    if (!dpy) {
        fprintf(stderr, "glxgears: Error: couldn't open display\n");
        return 1;
    }

    int screen = DefaultScreen(dpy);
    XVisualInfo *vi = glXChooseVisual(dpy, screen, NULL);
    if (!vi) {
        fprintf(stderr, "glxgears: Error: couldn't get visual\n");
        XCloseDisplay(dpy);
        return 1;
    }

    ctx = glXCreateContext(dpy, vi, NULL, GL_TRUE);
    if (!ctx) {
        fprintf(stderr, "glxgears: Error: couldn't create GLX context\n");
        XCloseDisplay(dpy);
        return 1;
    }

    Colormap cmap = XCreateColormap(dpy, RootWindow(dpy, screen), vi->visual, AllocNone);
    XSetWindowAttributes swa;
    swa.colormap = cmap;
    swa.border_pixel = 0;
    swa.event_mask = StructureNotifyMask | ExposureMask | KeyPressMask;

    win = XCreateWindow(dpy, RootWindow(dpy, screen), 100, 100, win_w, win_h, 0,
                        vi->depth, InputOutput, vi->visual,
                        CWBorderPixel | CWColormap | CWEventMask, &swa);

    XSizeHints hints;
    hints.flags = PPosition | PSize;
    hints.x = 100;
    hints.y = 100;
    hints.width = win_w;
    hints.height = win_h;
    XSetStandardProperties(dpy, win, "glxgears", "glxgears", None, argv, argc, &hints);

    XClassHint ch = {"glxgears", "FreeLinX"};
    XSetClassHint(dpy, win, &ch);

    wm_delete_window = XInternAtom(dpy, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(dpy, win, &wm_delete_window, 1);

    XMapWindow(dpy, win);
    glXMakeCurrent(dpy, win, ctx);

    printf("GL_RENDERER   = TinyGL 0.4 Software Rasterizer (FreeLinX)\n");
    printf("GL_VERSION    = 1.1 TinyGL\n");
    printf("GL_VENDOR     = FreeLinX Project\n");
    if (info) {
        printf("GL_EXTENSIONS = GL_EXT_texture_object\n");
        printf("Visual ID     = 0x%lx\n", vi->visualid);
    }
    fflush(stdout);

    init_scene();
    reshape(win_w, win_h);

    int frames = 0;
    double t_start = get_time();
    double t_last = t_start;
    int running = 1;

    while (running) {
        while (XPending(dpy) > 0) {
            XEvent ev;
            XNextEvent(dpy, &ev);
            if (ev.type == KeyPress) {
                KeySym sym = XLookupKeysym(&ev.xkey, 0);
                if (sym == XK_Escape || sym == XK_q || sym == XK_Q) {
                    running = 0;
                    break;
                } else if (sym == XK_Up) {
                    view_rotx += 5.0f;
                } else if (sym == XK_Down) {
                    view_rotx -= 5.0f;
                } else if (sym == XK_Left) {
                    view_roty += 5.0f;
                } else if (sym == XK_Right) {
                    view_roty -= 5.0f;
                }
            } else if (ev.type == ConfigureNotify) {
                if (ev.xconfigure.width != win_w || ev.xconfigure.height != win_h) {
                    win_w = ev.xconfigure.width;
                    win_h = ev.xconfigure.height;
                    reshape(win_w, win_h);
                }
            } else if (ev.type == ClientMessage) {
                if ((Atom)ev.xclient.data.l[0] == wm_delete_window) {
                    running = 0;
                    break;
                }
            }
        }

        if (!running) break;

        /* Advance gear angle by 70 degrees per second */
        double now = get_time();
        double dt = now - t_last;
        t_last = now;
        angle += (GLfloat)(70.0 * dt);
        if (angle > 360.0f) angle -= 360.0f;

        draw();
        glXSwapBuffers(dpy, win);
        frames++;

        /* Report FPS every 5.0 seconds */
        if (now - t_start >= 5.0) {
            double elapsed = now - t_start;
            double fps = (double)frames / elapsed;
            printf("%d frames in %3.1f seconds = %6.3f FPS\n", frames, elapsed, fps);
            fflush(stdout);
            frames = 0;
            t_start = now;
        }

        /* Brief yield so CPU doesn't spin 100% in loop when vsync/unmetered */
        usleep(1000); // 1ms sleep ~ up to 1000 fps max
    }

    glXDestroyContext(dpy, ctx);
    XDestroyWindow(dpy, win);
    XCloseDisplay(dpy);
    return 0;
}
