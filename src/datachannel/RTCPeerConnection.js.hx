package datachannel;

import js.html.rtc.DataChannelEvent;
import js.html.rtc.PeerConnection;
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
	var inner:PeerConnection;
	var _sdpGenerated = false;

	// The ICE servers to use.
	public var iceServers(default, null):Array<String>;
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

	// Called when the local description is set
	public dynamic function onLocalDescription(sdp:String, type:String) {}

	// Called when a local candidate is found
	public dynamic function onLocalCandidate(candidate:String) {}

	// Called when the state of the connection changes
	public dynamic function onStateChange(state:datachannel.RTCState):Void {}

	// Called when the gathering state of the connection changes
	public dynamic function onGatheringStateChange(state:datachannel.RTCGatheringState):Void {}

	// Called when a data channel that is created by remote is opened
	public dynamic function onDataChannel(dc:datachannel.RTCDataChannel):Void {}

	public function new(iceServers:Array<String>, bindAddress:String) {
		if (!RTC.inited)
			throw new RTCException("RTC is not initialized");
		var properServers:Array<Dynamic> = [];
		var authRe = ~/:(?:\/\/)?(\S*):(\S*)@/g;
		for (server in iceServers) {
			if (authRe.match(server)) {
				var proto = server.substr(0, server.indexOf(":"));
				var rest = server.substr(server.indexOf("@") + 1);
				properServers.push({
					urls: ['${proto}:${rest}'],
					username: authRe.matched(1),
					password: authRe.matched(2)
				});
			} else {
				properServers.push({
					urls: [server]
				});
			}
		}
		this.inner = new PeerConnection({
			iceServers: properServers,
		});
		this.iceServers = iceServers;
		this.dataChannels = [];
		setCallbacks();
	}

	// Closes the connection
	public function close() {
		this.inner.close();
	}

	function setCallbacks() {
		inner.onicecandidate = (c) -> {
			if (c.candidate != null && c.candidate.candidate != "")
				onLocalCandidate(c.candidate.candidate);
		}
		inner.oniceconnectionstatechange = () -> {
			switch (inner.iceConnectionState) {
				case CHECKING:
					state = RTC_CONNECTING;

				case CLOSED:
					state = RTC_CLOSED;

				case COMPLETED:
					{}

				case CONNECTED:
					state = RTC_CONNECTED;
				case DISCONNECTED:
					state = RTC_DISCONNECTED;
				case FAILED:
					state = RTC_FAILED;
				case NEW:
					state = RTC_NEW;
			}
			onStateChange(state);
		}
		inner.onicegatheringstatechange = () -> {
			switch (inner.iceGatheringState) {
				case COMPLETE:
					gatheringState = RTC_GATHERING_COMPLETE;
				case GATHERING:
					gatheringState = RTC_GATHERING_INPROGRESS;
				case NEW:
					gatheringState = RTC_GATHERING_NEW;
			}
			onGatheringStateChange(gatheringState);
		}
		inner.ondatachannel = (e:DataChannelEvent) -> {
			var dc = new RTCDataChannel(e.channel, this);
			dc.state = Open;
			this.dataChannels.push(dc);
			onDataChannel(dc);
		}
	}

	// Sets the remote description
	public function setRemoteDescription(sdp:String, type:String) {
		this.inner.setRemoteDescription({
			sdp: sdp,
			type: switch (type) {
				case "offer":
					OFFER;
				case "answer":
					ANSWER;
				case _:
					OFFER;
			}
		});
		this.remoteDescription = sdp;
		this.remoteDescriptionType = type;
		if (type == "offer" && !this._sdpGenerated) {
			this._sdpGenerated = true;
			inner.createAnswer().then(e -> {
				localDescription = e.sdp;
				localDescriptionType = switch (e.type) {
					case ANSWER:
						"answer";
					case OFFER:
						"offer";
					case _:
						"offer";
				};
				inner.setLocalDescription(e);
				onLocalDescription(e.sdp, localDescriptionType);
			});
		}
	}

	// Adds a remote candidate
	public function addRemoteCandidate(candidate:String) {
		if (this.remoteDescription == null)
			throw new RTCException("No remote description set!");
		this.inner.addIceCandidate({
			candidate: candidate
		});
	}

	// Creates a new data channel
	public function createDatachannel(label:String) {
		var dc:RTCDataChannel = null;
		dc = new RTCDataChannel(inner.createDataChannel(label), this);
		this.dataChannels.push(dc);
		if (!this._sdpGenerated) {
			this._sdpGenerated = true;
			inner.createOffer().then((sdp) -> {
				localDescription = sdp.sdp;
				localDescriptionType = switch (sdp.type) {
					case ANSWER:
						"answer";
					case OFFER:
						"offer";
					case _:
						"offer";
				};
				inner.setLocalDescription(sdp);
				onLocalDescription(sdp.sdp, localDescriptionType);
			});
		}
		return dc;
	}

	// Creates a new data channel with specified options
	public function createDatachannelWithOptions(label:String, unordered:Bool, maxRetransmits:Null<Int>, maxLifetime:Null<Int>) {
		var dc:RTCDataChannel = null;
		var reliable = maxRetransmits == 0 && maxLifetime == 0;
		dc = new RTCDataChannel(inner.createDataChannel(label, {
			ordered: !unordered,
			maxRetransmits: reliable ? js.Syntax.code("undefined") : (maxRetransmits != null ? maxRetransmits : js.Syntax.code("undefined")),
			maxPacketLifeTime: reliable ? js.Syntax.code("undefined") : (maxLifetime != null ? maxLifetime : js.Syntax.code("undefined")),
		}), this);
		this.dataChannels.push(dc);
		if (!this._sdpGenerated) {
			this._sdpGenerated = true;
			inner.createOffer().then((sdp) -> {
				localDescription = sdp.sdp;
				localDescriptionType = switch (sdp.type) {
					case ANSWER:
						"answer";
					case OFFER:
						"offer";
					case _:
						"offer";
				};
				inner.setLocalDescription(sdp);
				onLocalDescription(sdp.sdp, localDescriptionType);
			});
		}
		return dc;
	}
}
