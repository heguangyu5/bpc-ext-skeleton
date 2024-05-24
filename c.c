#include <ctype.h>

char *bpc_skel_strtoupper(char *s)
{
    char *p = s;
    while (*p) {
        *p = toupper(*p);
        p++;
    }
    return s;
}

char *bpc_skel_strtoupper_at(char *s, int index)
{
    *(s + index) = toupper(*(s + index));
    return s;
}
