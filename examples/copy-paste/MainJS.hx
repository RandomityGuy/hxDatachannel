import js.html.InputElement;
import js.html.TextAreaElement;
import datachannel.RTCPeerConnection;
import datachannel.RTCDataChannel;
import datachannel.RTC;
import js.Browser;

class MainJS {
	public static function main() {
		RTC.init();

		var pc = new RTCPeerConnection(["stun:stun.l.google.com:19302"], "0.0.0.0");

		var offerbtn = Browser.document.querySelector("#offerbtn");
		var answerbtn = Browser.document.querySelector("#answerbtn");
		var rcvanswerbtn = Browser.document.querySelector("#rcvanswerbtn");
		var localsdp = Browser.document.querySelector("#localsdp");
		var remotesdp:TextAreaElement = cast Browser.document.querySelector("#remotesdp");
		var status = Browser.document.querySelector("#connstatus");
		var chatlog = Browser.document.querySelector("#chatlog");
		var chatinput:InputElement = cast Browser.document.querySelector("#chatinput");

		var candidates = [];

		pc.onLocalCandidate = (candidate) -> {
			if (candidate != "")
				candidates.push('a=${candidate}');
		}

		pc.onGatheringStateChange = (state) -> {
			if (state == RTC_GATHERING_COMPLETE) {
				var sdpObj = StringTools.trim(pc.localDescription);
				sdpObj = sdpObj + '\r\n' + candidates.join('\r\n');

				localsdp.textContent = js.Browser.window.btoa(sdpObj);
			}
		}

		var dc:RTCDataChannel = null;

		pc.onDataChannel = (rdc) -> {
			dc = rdc;
			dc.onOpen = (n) -> {
				status.textContent = "Connection Status: Connected";
			}
			dc.onClosed = () -> {
				status.textContent = "Connection Status: Disconnected";
			}
			dc.onMessage = (m) -> {
				chatlog.textContent = chatlog.textContent + '\n<< ' + m;
			}
		}

		offerbtn.addEventListener('click', (e) -> {
			dc = pc.createDatachannel("test");
			dc.onOpen = (n) -> {
				status.textContent = "Connection Status: Connected";
			}
			dc.onClosed = () -> {
				status.textContent = "Connection Status: Disconnected";
			}
			dc.onMessage = (m) -> {
				chatlog.textContent = chatlog.textContent + '\n<< ' + m;
			}
		});

		answerbtn.addEventListener('click', (e) -> {
			pc.setRemoteDescription(js.Browser.window.atob(remotesdp.value), 'offer');
		});

		rcvanswerbtn.addEventListener('click', (e) -> {
			pc.setRemoteDescription(js.Browser.window.atob(remotesdp.value), 'answer');
		});

		chatinput.addEventListener('keyup', (e) -> {
			if (e.keyCode == 13) {
				var msg = chatinput.value;
				chatinput.value = "";
				if (dc != null)
					dc.sendMessage(msg);
				chatlog.textContent = chatlog.textContent + '\n>> ' + msg;
			}
		});
	}
}
