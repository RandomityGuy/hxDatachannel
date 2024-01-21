import datachannel.RTCPeerConnection;
import datachannel.RTCDataChannel;
import datachannel.RTC;

class MainHL {
	static function main() {
		RTC.init();
		var sdpTxt = null;
		var rtc = new RTCPeerConnection(["stun:stun.l.google.com:19302"], "0.0.0.0");

		var candidates = [];

		rtc.onLocalDescription = (desc, type) -> {
			sdpTxt = desc;
		}
		rtc.onGatheringStateChange = (state) -> {
			trace('Gathering state: ${state}');
			if (state == RTC_GATHERING_COMPLETE) {
				var sdpObj = StringTools.trim(sdpTxt);
				sdpObj = sdpObj + '\r\n' + candidates.join('\r\n');
				trace('Local description: \n${haxe.crypto.Base64.encode(haxe.io.Bytes.ofString(sdpObj))}');
			}
		}
		rtc.onStateChange = (state) -> {
			trace('State: ${state}');
		}
		rtc.onLocalCandidate = (candidate) -> {
			if (candidate != "")
				candidates.push('a=${candidate}');
		}
		var dc:RTCDataChannel = null;
		rtc.onDataChannel = (dct) -> {
			trace('Datachannel ${dct.name} opened!');
			dct.onOpen = (name) -> {
				trace('Datachannel ${name} opened!');
			}
			dct.onClosed = () -> {
				trace('Datachannel closed!');
			}
			dct.onError = (msg) -> {
				trace('Datachannel error: ${msg}');
			}
			dct.onMessage = (msgBytes) -> {
				trace('Datachannel message: ${msgBytes.toString()}');
			}
			dc = dct;
		}

		Sys.println("1. Offerer");
		Sys.println("2. Answerer");
		var ch = Sys.getChar(false);
		if (ch == '1'.code) {
			dc = rtc.createDatachannel("test");
			dc.onOpen = (name) -> {
				trace('Datachannel ${name} opened!');
			}
			dc.onClosed = () -> {
				trace('Datachannel closed!');
			}
			dc.onError = (msg) -> {
				trace('Datachannel error: ${msg}');
			}
			dc.onMessage = (msgBytes) -> {
				trace('Datachannel message: ${msgBytes.toString()}');
			}
		}

		var t = sys.thread.Thread.create(() -> {
			while (true) {
				RTC.processEvents();
			}
		});

		while (true) {
			Sys.println("1. Enter SDP.");
			Sys.println("2. Enter candidate.");
			Sys.println("3. Send");
			Sys.println("4. Stop");

			var ch = Sys.stdin().readLine();

			if (ch == "1") {
				var b64 = Sys.stdin().readLine();
				var sdp = haxe.crypto.Base64.decode(b64).toString();
				rtc.setRemoteDescription(sdp, dc != null ? "answer" : "offer");
			}
			if (ch == "2") {
				var candidate = Sys.stdin().readLine();
				rtc.addRemoteCandidate(candidate);
			}
			if (ch == "3") {
				var s = Sys.stdin().readLine();
				dc.sendMessage(s);
			}

			if (ch == "4") {
				break;
			}
		}

		RTC.finalize();
	}
}
