#ifndef _XMU_ATOMS_H_
#define _XMU_ATOMS_H_
#include <X11/Xatom.h>
#include <X11/Xresource.h>
#include <string.h>
#define XA_CLIPBOARD(d) XInternAtom(d, "CLIPBOARD", False)
#define XA_UTF8_STRING(d) XInternAtom(d, "UTF8_STRING", False)
#endif
