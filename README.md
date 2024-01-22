# HxDatachannel
WebRTC DataChannel bindings for Hashlink and JS (Browser)  
It makes use of [libdatachannel](https://github.com/paullouisageneau/libdatachannel) to provide WebRTC DataChannels for Hashlink.

# Build
Set the env/CMake vars HASHLINK_INCLUDE_DIR and HASHLINK_LIBRARY_DIR to Hashlink src and libhl directories respectively.  
Then build the native extension using CMake. See the ./circleci/config.yml for a working build configuration for Windows and Mac.\a
A precompiled Windows hdll is provided in Releases

# Installation
After compilation, copy the built datachannel.hdll to the same folder as Hashlink binary or your game's .hl file. Then install the Haxe library by doing either of the three:  
- `haxelib dev datachannel <path/to/this/repo>`
- `haxelib git datachannel https://github.com/RandomityGuy/hxDatachannel`
- `haxelib install datachannel`

# Usage
The API closely mimics the WebRTC Browser API at [MDN WebRTC API Docs](https://developer.mozilla.org/en-US/docs/Web/API/WebRTC_API). More documentation is available in the form of commented code.
```haxe
import datachannel.*;

class Main {
    static function main() {
        // Initialize the RTC extension
        RTC.init();

        var iceServers = ["stun:stun.l.google.com:19302"];

        // Create the RTCPeerConnection
        var rtc = new RTCPeerConnection(iceServers, "0.0.0.0");

        // Create a datachannel
        var dc = rtc.createDatachannel("name");

        // Set the remote description
        rtc.setRemoteDescription("description", "answer");

        // Hashlink needs this, you don't need a loop for JS
        while (true)
        {
            // Your application loop logic here
            // <code>
            // Process RTC events
            RTC.processEvents();
        }

        // Finalize the RTC extension
        RTC.finalize();
    }
}
```