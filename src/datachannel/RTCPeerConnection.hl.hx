package datachannel;

import hl.NativeArray;
import hl.Abstract;
import datachannel.RTC;
import datachannel.RTCException;
import datachannel.RTCDataChannel;
import datachannel.RTCDataChannel.DataChannelData;

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

typedef PeerConnectionData = Abstract<"hl_rtc_peerconnection">;

class RTCPeerConnection {
	var inner:PeerConnectionData;

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
		var na = new NativeArray(iceServers.length);
		for (i in 0...iceServers.length)
			na[i] = @:privateAccess iceServers[i].bytes.utf16ToUtf8(0, null);
		this.inner = create_peer_connection(na, bindAddress, portBegin >= 0 ? portBegin : 0, portEnd >= 0 ? portEnd : 0, mtu >= 0 ? mtu : 0,
			maxMessageSize >= 0 ? maxMessageSize : 0);
		this.iceServers = iceServers;
		this.bindAddress = bindAddress;
		this.portBegin = portBegin > 0 ? portBegin : 0;
		this.portEnd = portEnd > 0 ? portEnd : 0;
		this.mtu = mtu > 0 ? mtu : 0;
		this.maxMessageSize = maxMessageSize > 0 ? maxMessageSize : 0;
		this.dataChannels = [];
		setCallbacks();
	}

	// Closes the connection
	public function close() {
		close_peer_connection(this.inner);
	}

	function setCallbacks() {
		set_peer_connection_callbacks(this.inner, (a, b) -> {
			localDescription = @:privateAccess String.fromUTF8(a);
			localDescriptionType = @:privateAccess String.fromUTF8(b);
			onLocalDescription(localDescription, localDescriptionType);
		}, (a) -> {
			var astr = @:privateAccess String.fromUTF8(a);
			if (a != null && astr != "")
				onLocalCandidate(astr);
		}, (a) -> {
			onStateChange(a);
			state = a;
		}, (a) -> {
			onGatheringStateChange(a);
			gatheringState = a;
		});
		set_peerconnection_datachannel_cb(this.inner, (dcinner, dcname) -> {
			var dc:RTCDataChannel = null;
			var rel = @:privateAccess RTCDataChannel.get_datachannel_reliability(dcinner);
			dc = new RTCDataChannel(dcinner, dcname != null ? @:privateAccess String.fromUTF8(dcname) : null, this,
				rel.unordered, rel.maxRetransmits != 0 || rel.maxLifetime != 0 ? Unreliable(rel.maxRetransmits, rel.maxLifetime) : Reliable);
			dc.state = Open;
			this.dataChannels.push(dc);
			onDataChannel(dc);
		});
	}

	// Sets the remote description
	public function setRemoteDescription(sdp:String, type:String) {
		set_remote_description(this.inner, @:privateAccess sdp.bytes.utf16ToUtf8(0, null), type);
		this.remoteDescription = sdp;
		this.remoteDescriptionType = type;
	}

	// Adds a remote candidate
	public function addRemoteCandidate(candidate:String) {
		if (this.remoteDescription == null)
			throw new RTCException("No remote description set!");
		add_remote_candidate(this.inner, @:privateAccess candidate.bytes.utf16ToUtf8(0, null));
	}

	// Creates a new data channel
	public function createDatachannel(label:String) {
		var dc:RTCDataChannel = null;
		dc = new RTCDataChannel(create_datachannel(this.inner, label), label, this, false, Reliable);
		this.dataChannels.push(dc);
		return dc;
	}

	// Creates a new data channel with specified options
	public function createDatachannelWithOptions(label:String, unordered:Bool, maxRetransmits:Null<Int>, maxLifetime:Null<Int>) {
		var dc:RTCDataChannel = null;
		var maxTransmits = maxRetransmits != null ? maxRetransmits : 0;
		var maxLifetimeVar = maxLifetime != null ? maxLifetime : 0;
		dc = new RTCDataChannel(create_datachannel_ex(this.inner, label, unordered, maxTransmits, maxLifetimeVar), label, this, unordered,
			(maxRetransmits != 0 || maxLifetime != 0) ? Unreliable(maxRetransmits, maxLifetime) : Reliable);
		this.dataChannels.push(dc);
		return dc;
	}

	function get_localAddress():String {
		var b = get_local_address(this.inner);
		if (b == null)
			return null;
		return @:privateAccess String.fromUTF8(b);
	}

	function get_remoteAddress():String {
		var b = get_remote_address(this.inner);
		if (b == null)
			return null;
		return @:privateAccess String.fromUTF8(b);
	}

	@:hlNative("datachannel", "create_peer_connection") static function create_peer_connection(iceServers:hl.NativeArray<hl.Bytes>, bindAddress:String,
			portBegin:Int, portEnd:Int, mtu:Int, maxMessageSize:Int):PeerConnectionData {
		return null;
	}

	@:hlNative("datachannel", "close_peer_connection") static function close_peer_connection(pc:PeerConnectionData):Void {
		return;
	}

	@:hlNative("datachannel", "set_peer_connection_callbacks") static function set_peer_connection_callbacks(pc:PeerConnectionData,
			onDesc:(hl.Bytes, hl.Bytes) -> Void, onCandidate:hl.Bytes->Void, onStateChange:Int->Void, onGatheringStateChange:Int->Void):Void {
		return;
	}

	@:hlNative("datachannel", "set_remote_description") static function set_remote_description(pc:PeerConnectionData, sdp:hl.Bytes, type:String):Void {
		return;
	}

	@:hlNative("datachannel", "add_remote_candidate") static function add_remote_candidate(pc:PeerConnectionData, candidate:hl.Bytes):Void {
		return;
	}

	@:hlNative("datachannel", "create_datachannel") static function create_datachannel(pc:PeerConnectionData, name:String):DataChannelData {
		return null;
	}

	@:hlNative("datachannel", "create_datachannel_ex") static function create_datachannel_ex(pc:PeerConnectionData, name:String, unordered:Bool,
			maxRetransmits:Int, maxLifetime:Int):DataChannelData {
		return null;
	}

	@:hlNative("datachannel", "set_peerconnection_datachannel_cb") static function set_peerconnection_datachannel_cb(pc:PeerConnectionData,
			onOpen:(dc:DataChannelData, name:hl.Bytes) -> Void):Void {
		return;
	}

	@:hlNative("datachannel", "get_local_address") static function get_local_address(pc:PeerConnectionData):hl.Bytes {
		return null;
	}

	@:hlNative("datachannel", "get_remote_address") static function get_remote_address(pc:PeerConnectionData):hl.Bytes {
		return null;
	}
}
