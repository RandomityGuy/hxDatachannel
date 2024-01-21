import hx.ws.State;
import hx.ws.Log;
import hx.ws.HttpHeader;
import hx.ws.HttpResponse;
import hx.ws.HttpRequest;
import hx.ws.WebSocketServer;
import haxe.Json;
import datachannel.RTCPeerConnection;
import datachannel.RTC;
import hx.ws.SocketImpl;
import hx.ws.WebSocketHandler;
import hx.ws.Types;

class SignalingWS extends WebSocketHandler {
	static var pcs = [];

	public override function handshake(httpRequest:HttpRequest) {
		var httpResponse = new HttpResponse();

		httpResponse.headers.set(HttpHeader.SEC_WEBSOSCKET_VERSION, "13");
		httpResponse.headers.set("Access-Control-Allow-Origin", "*"); // Enable CORS pls, why do i have to override this entire function for a single line
		if (httpRequest.method != "GET" || httpRequest.httpVersion != "HTTP/1.1") {
			httpResponse.code = 400;
			httpResponse.text = "Bad";
			httpResponse.headers.set(HttpHeader.CONNECTION, "close");
			httpResponse.headers.set(HttpHeader.X_WEBSOCKET_REJECT_REASON, 'Bad request');
		} else if (httpRequest.headers.get(HttpHeader.SEC_WEBSOSCKET_VERSION) != "13") {
			httpResponse.code = 426;
			httpResponse.text = "Upgrade";
			httpResponse.headers.set(HttpHeader.CONNECTION, "close");
			httpResponse.headers.set(HttpHeader.X_WEBSOCKET_REJECT_REASON,
				'Unsupported websocket client version: ${httpRequest.headers.get(HttpHeader.SEC_WEBSOSCKET_VERSION)}, Only version 13 is supported.');
		} else if (httpRequest.headers.get(HttpHeader.UPGRADE) != "websocket") {
			httpResponse.code = 426;
			httpResponse.text = "Upgrade";
			httpResponse.headers.set(HttpHeader.CONNECTION, "close");
			httpResponse.headers.set(HttpHeader.X_WEBSOCKET_REJECT_REASON, 'Unsupported upgrade header: ${httpRequest.headers.get(HttpHeader.UPGRADE)}.');
		} else if (httpRequest.headers.get(HttpHeader.CONNECTION).indexOf("Upgrade") == -1) {
			httpResponse.code = 426;
			httpResponse.text = "Upgrade";
			httpResponse.headers.set(HttpHeader.CONNECTION, "close");
			httpResponse.headers.set(HttpHeader.X_WEBSOCKET_REJECT_REASON, 'Unsupported connection header: ${httpRequest.headers.get(HttpHeader.CONNECTION)}.');
		} else {
			Log.debug('Handshaking', id);
			var key = httpRequest.headers.get(HttpHeader.SEC_WEBSOCKET_KEY);
			var result = makeWSKeyResponse(key);
			Log.debug('Handshaking key - ${result}', id);

			httpResponse.code = 101;
			httpResponse.text = "Switching Protocols";
			httpResponse.headers.set(HttpHeader.UPGRADE, "websocket");
			httpResponse.headers.set(HttpHeader.CONNECTION, "Upgrade");
			httpResponse.headers.set(HttpHeader.SEC_WEBSOSCKET_ACCEPT, result);
		}

		sendHttpResponse(httpResponse);

		if (httpResponse.code == 101) {
			_onopenCalled = false;
			state = State.Head;
			Log.debug('Connected', id);
		} else {
			close();
		}
	}

	public function new(s:SocketImpl) {
		super(s);
		onmessage = function(message:MessageType) {
			switch (message) {
				case StrMessage(content):
					var sdpReply = Json.parse(content);

					var pc = new RTCPeerConnection(["stun:stun.l.google.com:19302"], "0.0.0.0");
					pcs.push(pc); // so it doesn't get gc'd

					pc.onDataChannel = (dc) -> {
						trace("Datachannel opened!");
						dc.onMessage = (msg) -> {
							trace('Received ${msg.length} bytes of message');
							dc.sendBytes(msg);
						}
					}

					pc.setRemoteDescription(sdpReply.sdp, sdpReply.type);
					trace('Remote Description: \n${sdpReply.sdp}');

					var localCandidates = [];

					pc.onLocalCandidate = (candidate) -> {
						localCandidates.push('a=${candidate}');
					}

					pc.onGatheringStateChange = (state) -> {
						if (state == RTC_GATHERING_COMPLETE) {
							var sdpObj = StringTools.trim(pc.localDescription);
							sdpObj = sdpObj + '\r\n' + localCandidates.join('\r\n');

							trace('Local Description: \n${sdpObj}');

							send(Json.stringify({
								type: 'answer',
								sdp: sdpObj
							}));
						}
					}

				case _:
					{}
			}
		}
		onerror = function(error) {
			trace(id + ". ERROR: " + error);
		}
	}
}

class Main {
	public static function main() {
		var ws = new WebSocketServer<SignalingWS>("localhost", 8080, 10);
		ws.start();

		RTC.init();

		var stopping = false;

		#if hl
		while (true) {
			RTC.processEvents();
			ws.tick();
			if (stopping)
				break;
		}

		RTC.finalize();
		#end
	}
}
