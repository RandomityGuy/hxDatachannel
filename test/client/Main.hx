import hx.ws.WebSocket;
import hx.ws.Types.MessageType;
import haxe.Json;
import datachannel.RTCPeerConnection;
import datachannel.RTC;

class Main {
	static function time() {
		#if hl
		return Sys.time();
		#end
		#if js
		return js.lib.Date.now() / 1000;
		#end
	}

	public static function main() {
		var closing = false;

		var sdpObj = null;
		var localCandidates = [];

		var beginTime = 0.0;

		RTC.init();

		var pc = new RTCPeerConnection(["stun:stun.l.google.com:19302"], "0.0.0.0");

		var ws = new WebSocket("ws://localhost:8080");
		ws.onmessage = (msg) -> {
			switch (msg) {
				case StrMessage(content):
					{
						var sdpReply = Json.parse(content);
						pc.setRemoteDescription(sdpReply.sdp, sdpReply.type);

						trace('Remote Description: \n${sdpReply.sdp}');
					}

				case _:
					{}
			}
		};

		pc.onLocalDescription = (sdp, type) -> {
			sdpObj = sdp;
		};
		pc.onLocalCandidate = (candidate) -> {
			if (candidate != "")
				localCandidates.push('a=${candidate}');
		};
		pc.onGatheringStateChange = (state) -> {
			if (state == RTC_GATHERING_COMPLETE) {
				beginTime = time();

				sdpObj = StringTools.trim(sdpObj);
				sdpObj = sdpObj + '\r\n' + localCandidates.join('\r\n');

				trace('Local Description: \n${sdpObj}');

				ws.send(Json.stringify({
					sdp: sdpObj,
					type: 'offer'
				}));
			}
		}
		pc.onStateChange = (state) -> {
			if (state == RTC_FAILED) {
				closing = true;
				trace('Test failed!');
			}
		};

		var dc = pc.createDatachannel('test');

		var randomBytes = null;

		dc.onOpen = (name) -> {
			trace('Datachannel Opened!');

			var randomBytesBuf = new haxe.io.BytesBuffer();
			for (i in 0...32) {
				randomBytesBuf.addByte(Std.int(255 * Math.random()));
			}

			randomBytes = randomBytesBuf.getBytes();

			dc.sendBytes(randomBytes);
		}

		dc.onMessage = (bytes) -> {
			for (i in 0...bytes.length) {
				if (bytes.get(i) != randomBytes.get(i)) {
					trace('Test failed!');
					closing = true;
					return;
				}
			}
			trace('Test passed!');
			closing = true;
		}

		#if hl
		// Loop only needed in native HL
		while (true) {
			RTC.processEvents();

			if (closing)
				break;

			if (beginTime != 0 && (time() - beginTime) > 10) { // 10 seconds max
				trace('Test failed!');
				break;
			}
		}
		#end

		RTC.finalize();
	}
}
