package datachannel;

import js.html.rtc.DataChannelType;
import js.html.rtc.DataChannel;

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
	var inner:DataChannel;

	// The name of the DataChannel
	public var name(get, null):String;
	// The RTCPeerConnection this DataChannel belongs to
	public var peerConnection(default, null):RTCPeerConnection;
	// Whether this DataChannel is ordered or not
	public var unordered(get, null):Bool;
	// The reliability of this DataChannel
	public var reliability(get, null):RTCDataChannelReliability;
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

	function new(inner:DataChannel, pc:datachannel.RTCPeerConnection) {
		this.inner = inner;
		this.inner.binaryType = DataChannelType.ARRAYBUFFER;
		this.peerConnection = pc;
		this.state = Open;
		setCallbacks();
	}

	function setCallbacks() {
		inner.onopen = () -> {
			state = Open;
			onOpen(inner.label);
		}
		inner.onclose = () -> {
			state = Closed;
			onClosed();
		}
		inner.onbufferedamountlow = () -> {
			onBufferedAmountLow();
		}
		inner.onerror = (e) -> {
			state = Error;
			onError(e.error.message);
		}
		inner.onmessage = (m:js.html.MessageEvent) -> {
			if (m.data is String) {
				onMessage(m.data);
			} else {}
			onMessage(haxe.io.Bytes.ofData(m.data));
		}
	}

	// Send a string message
	public function sendMessage(m:String) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
		inner.send(m);
	}

	// Send a binary message
	public function sendBytes(b:haxe.io.Bytes) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
		inner.send(b.getData());
	}

	function get_bufferedAmount():Int {
		return inner.bufferedAmount;
	}

	function get_bufferedAmountLowThreshold():Int {
		return inner.bufferedAmountLowThreshold;
	}

	function set_bufferedAmountLowThreshold(val:Int):Int {
		inner.bufferedAmountLowThreshold = val;
		return val;
	}

	function get_name():String {
		return inner.label;
	}

	function get_unordered():Bool {
		return !inner.ordered;
	}

	function get_reliability():RTCDataChannelReliability {
		if (inner.reliable)
			return Reliable;
		else
			return Unreliable(inner.maxRetransmits, inner.maxPacketLifeTime);
	}
}
