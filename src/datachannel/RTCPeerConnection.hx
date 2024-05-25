package datachannel;

import datachannel.RTC;
import datachannel.RTCException;
import datachannel.RTCDataChannel;

enum abstract RTCState(Int) from Int to Int {
	var RTC_NEW = 0;
	var RTC_CONNECTING = 1;
	var RTC_CONNECTED = 2;
	var RTC_DISCONNECTED = 3;
	var RTC_FAILED = 4;
	var RTC_CLOSED = 5;
}

enum abstract RTCGatheringState(Int) from Int to Int {
	var RTC_GATHERING_NEW = 0;
	var RTC_GATHERING_INPROGRESS = 1;
	var RTC_GATHERING_COMPLETE = 2;
}

class RTCPeerConnection {
	// The ICE servers to use.
	public var iceServers(default, null):Array<String>;
	// The address it is bound to [HL only]
	public var bindAddress(default, null):String;
	// The port range to use [HL only]
	public var portBegin(default, null):Int;
	// The port range to use [HL only]
	public var portEnd(default, null):Int;
	// The maximum transmission unit [HL only]
	public var mtu(default, null):Int;
	// The maximum message size [HL only]
	public var maxMessageSize(default, null):Int;
	// The current state
	public var state(default, null):RTCState;
	// The current gathering state
	public var gatheringState(default, null):RTCGatheringState;
	// The remote description
	public var remoteDescription(default, null):String;
	// The type of the remote description
	public var remoteDescriptionType(default, null):String;
	// The local description
	public var localDescription(default, null):String;
	// The type of the local description
	public var localDescriptionType(default, null):String;
	// The currently active data channels
	public var dataChannels(default, null):Array<RTCDataChannel>;
	// The address of the local peer [HL only]
	public var localAddress(get, never):String;
	// The address of the remote peer [HL only]
	public var remoteAddress(get, never):String;

	// Called when the local description is set
	public dynamic function onLocalDescription(sdp:String, type:String) {}

	// Called when a local candidate is found
	public dynamic function onLocalCandidate(candidate:String) {}

	// Called when the state of the connection changes
	public dynamic function onStateChange(state:RTCState) {}

	// Called when the gathering state of the connection changes
	public dynamic function onGatheringStateChange(state:RTCGatheringState) {}

	// Called when a data channel that is created by remote is opened
	public dynamic function onDataChannel(dc:RTCDataChannel) {}

	public function new(iceServers:Array<String>, bindAddress:String, portBegin:Int = 0, portEnd:Int = 0, mtu:Int = 0, maxMessageSize:Int = 0) {
		if (!RTC.inited)
			throw new RTCException("RTC is not initialized");
		this.iceServers = iceServers;
		this.bindAddress = bindAddress;
		this.portBegin = portBegin > 0 ? portBegin : 0;
		this.portEnd = portEnd > 0 ? portEnd : 0;
		this.mtu = mtu > 0 ? mtu : 0;
		this.maxMessageSize = maxMessageSize > 0 ? maxMessageSize : 0;
		this.dataChannels = [];
	}

	// Closes the connection
	public function close() {}

	// Sets the remote description
	public function setRemoteDescription(sdp:String, type:String) {
		this.remoteDescription = sdp;
		this.remoteDescriptionType = type;
	}

	// Adds a remote candidate
	public function addRemoteCandidate(candidate:String) {
		if (this.remoteDescription == null)
			throw new RTCException("No remote description set!");
	}

	// Creates a new data channel
	public function createDatachannel(label:String):RTCDataChannel {
		return null;
	}

	// Creates a new data channel with specified options
	public function createDatachannelWithOptions(label:String, unordered:Bool, maxRetransmits:Null<Int>, maxLifetime:Null<Int>):RTCDataChannel {
		return null;
	}

	function get_localAddress():String {
		return null;
	}

	function get_remoteAddress():String {
		return null;
	}
}
