KNOWN ISSUES-

Right now, this does not update light data for lights that are already in the frustum. 
This means position info (or any other info) is not updated until a light leaves and reenters the frustum.

Vita version will possibly need to be migrated to float buffers instead of compute, 
if it turns out Unity's compute buffer support is in fact inconsistent

How this works-

Event Broadcaster manages timed frame tick events for us to subscribe to.
Light Buffer Managermanage the light buffer build/send process.
Light Visibility manages each light's own self, and self populates.

In the prefabs folder you will find prefabs for LightBufferManager and EventBroadcaster.
Drag those into your hierarchy.
Add LightVisibility.cs to each light, making sure to set a tick interval for checking visibility.

TO DO-

Add selector for specular and diffuse terms (see half3 spec in LightingFastest.cginc to set the spec term to test their output)
Split light info into a static data buffer, and a dynamic light ID buffer so we can reduce the data needed each tick
Much more shader work, incl shadows, Bakery support.