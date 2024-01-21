package datachannel;

@:allow(datachannel.RTCPeerConnection)
class RTC {
	static var inited:Bool;

	#if hl
	// Processes the WebRTC event loop
	@:hlNative("datachannel", "process_events") public static function processEvents():Void {}

	@:hlNative("datachannel", "initialize") static function _init():Void {}

	@:hlNative("datachannel", "finalize") static function _finalize():Void {}
	#end

	#if js
	// Processes the WebRTC event loop, no-op in JS
	public static function processEvents():Void {}
	#end

	// Initializes the WebRTC module
	public static function init() {
		if (!inited) {
			#if hl
			_init();
			#end
			inited = true;
		}
	}

	// Finalizes the WebRTC module
	public static function finalize() {
		if (inited) {
			#if hl
			_finalize();
			#end
			inited = false;
		}
	}
}
