package datachannel;

enum RTCDataChannelReliability {
	Reliable;
	Unreliable(maxRetransmits:Int, maxLifetime:Int);
}

enum RTCDataChannelState {
	Closed;
	Open;
	Error;
}

@:allow(datachannel.RTCPeerConnection)
class RTCDataChannel {
	// The name of the DataChannel
	public var name(default, null):String;
	// The RTCPeerConnection this DataChannel belongs to
	public var peerConnection(default, null):RTCPeerConnection;
	// Whether this DataChannel is ordered or not
	public var unordered(default, null):Bool;
	// The reliability of this DataChannel
	public var reliability(default, null):RTCDataChannelReliability;
	// The state of this DataChannel
	public var state(default, null):RTCDataChannelState;
	// The number of bytes of data that have been queued to be sent
	public var bufferedAmount(get, never):Int;
	// Specifies the number of bytes of buffered outgoing data that is considered "low". The default value is 0.
	public var bufferedAmountLowThreshold(get, set):Int;

	// Called when the DataChannel is opened
	public dynamic function onOpen(name:String) {}

	// Called when the DataChannel is closed
	public dynamic function onClosed() {}

	// Called when the DataChannel encounters an error
	public dynamic function onError(msg:String) {}

	// Called when a message is received
	public dynamic function onMessage(msg:haxe.io.Bytes) {}

	// Called when the buffered amount is considered low
	public dynamic function onBufferedAmountLow() {}

	// Send a string message
	public function sendMessage(m:String) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
	}

	// Send a binary message
	public function sendBytes(b:haxe.io.Bytes) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
	}

	function get_bufferedAmount():Int {
		return 0;
	}

	function get_bufferedAmountLowThreshold():Int {
		return 0;
	}

	function set_bufferedAmountLowThreshold(val:Int):Int {
		return 0;
	}
}
