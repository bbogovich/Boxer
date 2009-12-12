/*
    SDL - Simple DirectMedia Layer
    Copyright (C) 1997-2003  Sam Lantinga

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Library General Public
    License as published by the Free Software Foundation; either
    version 2 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Library General Public License for more details.

    You should have received a copy of the GNU Library General Public
    License along with this library; if not, write to the Free
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

    Sam Lantinga
    slouken@libsdl.org
*/
#include "SDL_config.h"

#include "SDL_QuartzVideo.h"
#include "SDL_QuartzWM.h"
#include "SDL_QuartzWindow.h"


/*
    This function makes the *SDL region* of the window 100% opaque. 
    The genie effect uses the alpha component. Otherwise,
    it doesn't seem to matter what value it has.
*/
static void QZ_SetPortAlphaOpaque () {
    
    SDL_Surface *surface = current_video->screen;
    int bpp;
    
    bpp = surface->format->BitsPerPixel;
    
    if (bpp == 32) {
    
        Uint32    *pixels = (Uint32*) surface->pixels;
        Uint32    rowPixels = surface->pitch / 4;
        Uint32    i, j;
        
        for (i = 0; i < surface->h; i++)
            for (j = 0; j < surface->w; j++) {
        
                pixels[ (i * rowPixels) + j ] |= 0xFF000000;
            }
    }
}

@implementation SDL_QuartzWindow

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag
{
	
    /*
        If the video surface is NULL, this originated from QZ_SetVideoMode,
        so don't send the resize event. 
    */
    SDL_VideoDevice *this = (SDL_VideoDevice*)current_video;
    
    if (this && SDL_VideoSurface == NULL) {

        [ super setFrame:frameRect display:flag ];
    }
    else if (this && qz_window) {
        NSRect newViewFrame;
        
        [ super setFrame:frameRect display:flag ];
        
        newViewFrame = [ window_view frame ];
        
        SDL_PrivateResize (newViewFrame.size.width, newViewFrame.size.height);

        /* If not OpenGL, we have to update the pixels and pitch */
        if ( ! ( SDL_VideoSurface->flags & SDL_OPENGL ) ) {
            
            CGrafPtr thePort = [ window_view qdPort ];
            LockPortBits ( thePort );
            
            SDL_VideoSurface->pixels = GetPixBaseAddr ( GetPortPixMap ( thePort ) );
            SDL_VideoSurface->pitch  = GetPixRowBytes ( GetPortPixMap ( thePort ) );
                        
            /* 
                SDL_VideoSurface->pixels now points to the window's pixels
                We want it to point to the *view's* pixels 
            */
            { 
                int vOffset = [ qz_window frame ].size.height - 
                    newViewFrame.size.height - newViewFrame.origin.y;
                
                int hOffset = newViewFrame.origin.x;
                        
                SDL_VideoSurface->pixels = (Uint8 *)SDL_VideoSurface->pixels + (vOffset * SDL_VideoSurface->pitch) + hOffset * (device_bpp/8);
            }
            
            UnlockPortBits ( thePort );
        }
    }
}

- (void) applicationWillUnhide:(NSNotification*)notification
{
    SDL_VideoDevice *this = (SDL_VideoDevice*)current_video;
    
    if ( this ) {
    
        /* make sure pixels are fully opaque */
        if (! ( SDL_VideoSurface->flags & SDL_OPENGL ) )
            QZ_SetPortAlphaOpaque ();
          
        /* save current visible SDL surface */
		//Disabled 2009-01-24 by Alun Bestor: this is breaking unhide when using a NIB file
       // [ self cacheImageInRect:[ window_view frame ] ];
    }
}

- (void) applicationDidUnhide:(NSNotification*)notification
{
    /* restore cached image, since it may not be current, post expose event too */
    [ self restoreCachedImage ];
    
    /* SDL_PrivateExpose (); */
	
	SDL_PrivateAppActive (1, SDL_APPACTIVE);
}

//This should be handled by SDLMain, but cannot, because SDLMain lives in another library and can't access SDL_PrivateAppActive and oh god I hate this
- (void) applicationDidHide: (NSNotification *)notification
{
    SDL_PrivateAppActive (0, SDL_APPACTIVE);
}

- (id)initWithContentRect:(NSRect)contentRect styleMask:(unsigned int)styleMask backing:(NSBackingStoreType)backingType defer:(BOOL)flag
{
    /* Make our window subclass receive these application notifications */
	id center = [ NSNotificationCenter defaultCenter ];

	[ center addObserver:self selector:@selector(applicationDidHide:) name:NSApplicationDidHideNotification object:NSApp ];
    [ center addObserver:self selector:@selector(applicationDidUnhide:) name:NSApplicationDidUnhideNotification object:NSApp ];
	[ center addObserver:self selector:@selector(applicationWillUnhide:) name:NSApplicationWillUnhideNotification object:NSApp ];

	return [ super initWithContentRect:contentRect styleMask:styleMask backing:backingType defer:flag ];
}
@end

@implementation SDL_QuartzWindowDelegate
- (BOOL)windowShouldClose:(id)sender
{
    SDL_PrivateQuit();
    return NO;
}


- (void)windowDidBecomeKey:(NSNotification *)notification
{
    QZ_DoActivate (current_video);
}

- (void)windowDidResignKey:(NSNotification *)notification
{
    QZ_DoDeactivate (current_video);
}

//Moved 2009-01-29 from SDL_QuartzWindow miniaturize
- (void)windowWillMiniaturize:(NSNotification *)notification
{
    if (SDL_VideoSurface->flags & SDL_OPENGL) {
    
        /* 
            Future: Grab framebuffer and put into NSImage
            [ qz_window setMiniwindowImage:image ];
        */
    }
    else {
        
        /* make the alpha channel opaque so anim won't have holes in it */
        QZ_SetPortAlphaOpaque ();
    }
    
    /* window is hidden now */
    SDL_PrivateAppActive (0, SDL_APPACTIVE);
}

/* we override these methods to fix the miniaturize animation/dock icon bug */
- (void)windowWillDeminiaturize:(NSNotification *)notification
{
     SDL_VideoDevice *this = (SDL_VideoDevice*)current_video;
    
    /* make sure pixels are fully opaque */
    if (! ( SDL_VideoSurface->flags & SDL_OPENGL ) )
        QZ_SetPortAlphaOpaque ();
    
    /* save current visible SDL surface */
    [ [notification object] cacheImageInRect:[ window_view frame ] ];
}

- (void)windowDidDeminiaturize:(NSNotification *)notification
{
    /* restore visible SDL surface */
    [ [ notification object ] restoreCachedImage ];
    
    /* window is visible again */
    SDL_PrivateAppActive (1, SDL_APPACTIVE);
}

@end

@implementation SDL_QuartzView

- (void)resetCursorRects
{
    SDL_Cursor *sdlc = SDL_GetCursor();
    if (sdlc != NULL && sdlc->wm_cursor != NULL) {
        [self addCursorRect: [self visibleRect] cursor: sdlc->wm_cursor->nscursor];
    }
}

@end
