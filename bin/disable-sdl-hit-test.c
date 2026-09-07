#define SDL_MAIN_HANDLED

typedef struct SDL_Window SDL_Window;
typedef int (*SDL_HitTest)(SDL_Window *, const void *, void *);

/* FS-UAE uses this only for its custom title-bar hit testing. A background
 * layer has no title bar and must not ask the Wayland backend to configure
 * hit testing. */
int SDL_SetWindowHitTest(SDL_Window *window, SDL_HitTest callback, void *data) {
    (void)window;
    (void)callback;
    (void)data;
    return 0;
}
