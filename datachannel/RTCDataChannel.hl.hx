package datachannel;

import datachannel.RTCPeerConnection;
import datachannel.RTCException;
import hl.NativeArray;
import hl.Abstract;

enum RTCDataChannelReliability {
	Reliable;
	Unreliable(maxRetransmits:Int, maxLifetime:Int);
}

enum RTCDataChannelState {
	Closed;
	Open;
	Error;
}

typedef DataChannelData = Abstract<"hl_rtc_datachannel">;

@:allow(datachannel.RTCPeerConnection)
class RTCDataChannel {
	var inner:DataChannelData;

	var _bufferedAmountLowThreshold:Int;

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

	function new(inner:DataChannelData, name:String, pc:datachannel.RTCPeerConnection, unordered:Bool, reliability:RTCDataChannelReliability) {
		this.inner = inner;
		this.name = name;
		this.peerConnection = pc;
		this.unordered = unordered;
		this.reliability = reliability;
		this.state = Closed;
		this._bufferedAmountLowThreshold = 0;
		setCallbacks();
	}

	function setCallbacks() {
		set_datachannel_callbacks(this.inner, (n) -> {
			state = Open;
			n != null ? onOpen(@:privateAccess String.fromUTF8(n)) : onOpen(null);
		}, () -> {
			state = Closed;
			onClosed();
		}, (e) -> {
			state = Error;
			onError(@:privateAccess String.fromUTF8(e));
		}, (b, l) -> {
			onMessage(b.toBytes(l));
		}, () -> {
			onBufferedAmountLow();
		});
	}

	// Send a string message
	public function sendMessage(m:String) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
		var bytes = haxe.io.Bytes.ofString(m);
		send_message(this.inner, bytes.getData().bytes, bytes.length);
	}

	// Send a binary message
	public function sendBytes(b:haxe.io.Bytes) {
		if (this.state != Open)
			throw new RTCException("DataChannel is not open!");
		send_message(this.inner, b.getData().bytes, b.length);
	}

	function get_bufferedAmount():Int {
		return get_buffered_amount(this.inner);
	}

	function get_bufferedAmountLowThreshold():Int {
		return _bufferedAmountLowThreshold;
	}

	function set_bufferedAmountLowThreshold(val:Int):Int {
		set_buffered_amount_low_threshold(this.inner, val);
		_bufferedAmountLowThreshold = val;
		return val;
	}

	@:hlNative("datachannel", "set_datachannel_callbacks") static function set_datachannel_callbacks(dc:DataChannelData, onOpen:(name:hl.Bytes) -> Void,
		onClose:() -> Void, onError:(b:hl.Bytes) -> Void, onMessage:(b:hl.Bytes, l:Int) -> Void, onBufferLow:() -> Void):Void {}

	@:hlNative("datachannel", "get_datachannel_reliability") static function get_datachannel_reliability(dc:DataChannelData):Dynamic {
		return null;
	}

	@:hlNative("datachannel", "datachannel_send_message") static function send_message(dc:DataChannelData, bytes:hl.Bytes, size:Int):Void {}

	@:hlNative("datachannel", "get_buffered_amount") static function get_buffered_amount(dc:DataChannelData):Int {
		return 0;
	}

	@:hlNative("datachannel", "set_buffered_amount_low_threshold") static function set_buffered_amount_low_threshold(dc:DataChannelData, val:Int):Void {
		return;
	}
}
