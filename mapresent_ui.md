# Mapresent UI overview

Here's an overview of the parts of the app that I've been thinking about as a way to try to formalize them for UI thinking. 

## Vocabulary

Here is how I've been referring to things in code and in my own planning, just for reference. 

![](https://raw.github.com/mapbox/Mapresent/master/mapresent_ui.png)

## Some Areas of Unexplored Development

 * Bookmarking themes - see *Theme Browsing* below. 
 * 3D map transitions. 
 * Animated map points and lines. Think *Indiana Jones* travel maps. 
 * Playing back drawings as drawn, not all at once. 
 * Multimedia embedded on map (photos, videos, audio). 
 * A way to edit presentation markers (duration, animation timing curve, audio volume, etc.).

## Thoughts on the Existing Interface

 * It would be good to have a way to do simple play and pause when in fullscreen mode. Currently, dragging the map manually during playback pauses the presentation so that the presenter can explore in more detail. Then, they should be able to pick up again where they left off without going back to the editing view. 
 * We will probably want a multiple document load & save interface, perhaps like our other app, and allow export of video that doesn't overwrite the last export. 
 * Direct manipulation is key for things like markers and annotations on the map. The existing table in the inspector view is more for debugging purposes than usefulness (though you can delete markers there currently by swiping). See *Keynote* for an example of direct manipulation of presentation properties, rather than primary selection and secondary editing as on the desktop. Perhaps we could go widescreen and lose the inspector view allowing the top two-thirds to be the map and bottom one-third to be the timeline. 
 * The timeline should be more continuous, rather than like a keyframe indicator. For example, the red map placement markers represent transitions, but the entire horizontal of the timeline is occupied by views of the map in a presentation. We need to indicate continuity here. 

### Audio

Not a lot to change here. We will probably want volume adjustment as well as basic audio clipping and editing in the timeline. 

### Theme browsing

We need a way to browse *all* of the freely-available themes for use, and we want to emphasize the potential for customization if the user signs up for MapBox Hosting. We want a clear distinction between full-world and partial-world layers, because the former change the visible "theme" of the presentation at a point in time, but the latter will eventually be able to be faded in (or other transitions) during the presentation as part of the visualization. It would be nice to have a bookmarking feature to denote favorite themes for use in presentations and an easy way to get to them. 

Right now, we just allow (rather inefficient and non-bookmarkable) browsing of all of `mapbox`'s full-world layers. 

### Drawing

In addition to the current color palette and line width selection, we'll want line types (dashed, dotted, etc.), a color wheel for unlimited color selection, basic vector shapes (squares, circles, arcs, etc.), and points. We'll also want selection and editing of existing drawing components, and possibly a way to indicate "canvas drawings" (the current style, like a football play screen) and "geo drawings", which become vectors attached to points on the map and that pan and zoom with the map. 