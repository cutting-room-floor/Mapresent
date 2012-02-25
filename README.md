# Mapresent

Mapresent aims to be a geographic-focused presentation tool. The user will be able to present locations, themes, data, transitions, and voice narration on maps, then play the presentation on an external display or export and upload it to a video sharing service. 

Check out the announcement blog post: http://mapbox.com/blog/mapresent-presentation-tool-ipad/

The sort of thing you'd get out of this would be, say, a YouTube-uploaded HD video of a map presentation that goes like this:

 * Throughout, a voice track narrates the presentation.
 * Start with 3D view of the world, Blue Marble theme.
 * Points appear, animated, of major spots where US imports oil from.
 * Map zooms to 2D view of a particular region of focus, theme changing to a more World Light-like presentation theme, audio adds more context.
 * Map zooms back out to 3D Blue Marble, then in to US World Light, fading in Energy Dept. layer of alternative fueling stations nationwide.

Additionally, this app could, when used live instead of watched via exported video, have the audio track muted, with a live presenter instead, who can grab and adjust the intermediary points to explore or focus in more depth. At any point, the play button can be hit again and the next "waypoint" in the presentation is moved to, picking up where it left off before the interruption. 

### Complete

This stuff is working, albeit roughly. 

 * Capture of map center & zoom transitions. 
 * Addition of audio bits to presentation. 
 * Basic map theme changes using a book page metaphor. 
 * Saving presentation work on edits and when backgrounding app. 
 * Able to retrieve copy of presentation from app via iTunes file sharing. 
 * Playback automatically stops at end of presentation. 
 * Export to video on disk. 
 * Viewing (including in AirPlay), emailing, and opening exported video in other apps. 
 * Fullscreen map playback. 
 * Modal, cancellable export screen. 
 * Button for rewinding to beginning. 
 * Unlimited-length scrolling timeline. 
 * Device is prevented from auto-sleep when exporting (for now). 
 * Nice-looking audio record interface. 
 * Drawing variable color & width lines on map and having them appear at points in the presentation.
 * Clearing all drawings from the map at points in the presentation. 

### Todo

Pipe dreams of future functionality & things that need to happen. 

 * Fix crash when zooming too far into maps with Alpstein. 
 * Bookmark favorite [MapBox Hosting](http://tiles.mapbox.com/) themes for easier access. 
 * Improve tile caching. No real reason to expire remote tiles unless the user wants to do so manually. 
 * Experiment with 3D transitions using [WhirlyGlobe MBTiles support](http://code.google.com/p/whirlyglobe/issues/detail?id=1). Will require use of local tiles. 
 * Allow for points, shapes, and other annotations to be added to the presentation screen. 
 * Allow for animated annotations to the map. 
 * Allow for drawings to be played back as drawn, not all at once. 
 * Allow embedding of audio, video, and photo media into presentation. 
 * Allow dragging of timeline items directly to rearrange. 
 * Palette UI for editing fine details of selected timeline item (duration, timing curve, volume, etc.)
 * Allow drawings to stick to the map during pans & zooms as geo vectors, not just drawings. 