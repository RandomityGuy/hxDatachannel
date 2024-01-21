import hxd.Key;
import haxe.Json;
import datachannel.RTCDataChannel;
import datachannel.RTCPeerConnection;
import hx.ws.WebSocket;
import datachannel.RTC;
import hxd.App;
import hx.ws.Types.MessageType;

class Main extends App {
	var fui:h2d.Flow;
	var ws:WebSocket;
	var pc:RTCPeerConnection;
	var dc:RTCDataChannel;

	function addButton(label:String, onClick:Void->Void) {
		var f = new h2d.Flow(fui);
		f.padding = 5;
		f.paddingBottom = 7;
		f.backgroundTile = h2d.Tile.fromColor(0x404040);
		var tf = new h2d.Text(hxd.res.DefaultFont.get(), f);
		tf.text = label;
		f.enableInteractive = true;
		f.interactive.cursor = Button;
		f.interactive.onClick = function(_) onClick();
		f.interactive.onOver = function(_) f.backgroundTile = h2d.Tile.fromColor(0x606060);
		f.interactive.onOut = function(_) f.backgroundTile = h2d.Tile.fromColor(0x404040);
		return f;
	}

	function addText(text = "") {
		var tf = new h2d.Text(hxd.res.DefaultFont.get(), fui);
		tf.text = text;
		return tf;
	}

	override function init() {
		super.init();

		#if js
		var canvas = js.Browser.document.getElementById("webgl");
		canvas.addEventListener('keypress', (e:js.html.KeyboardEvent) -> {
			@:privateAccess hxd.Window.getInstance().onKeyPress(e);
		});
		canvas.addEventListener('keydown', (e:js.html.KeyboardEvent) -> {
			var buttonCode = (e.keyCode);
			@:privateAccess Key.keyPressed[buttonCode] = Key.getFrame();
			@:privateAccess hxd.Window.getInstance().onKeyDown(e);
		});
		canvas.addEventListener('keyup', (e:js.html.KeyboardEvent) -> {
			var buttonCode = (e.keyCode);
			@:privateAccess Key.keyPressed[buttonCode] = -Key.getFrame();
			@:privateAccess hxd.Window.getInstance().onKeyUp(e);
		});
		js.Browser.window.addEventListener('keypress', (e:js.html.KeyboardEvent) -> {
			@:privateAccess hxd.Window.getInstance().onKeyPress(e);
		});
		js.Browser.window.addEventListener('keydown', (e:js.html.KeyboardEvent) -> {
			var buttonCode = (e.keyCode);
			@:privateAccess Key.keyPressed[buttonCode] = Key.getFrame();
			@:privateAccess hxd.Window.getInstance().onKeyDown(e);
		});
		js.Browser.window.addEventListener('keyup', (e:js.html.KeyboardEvent) -> {
			var buttonCode = (e.keyCode);
			@:privateAccess Key.keyPressed[buttonCode] = -Key.getFrame();
			@:privateAccess hxd.Window.getInstance().onKeyUp(e);
		});
		hxd.Window.getInstance().removeEventTarget(@:privateAccess Key.onEvent);
		#end

		engine.backgroundColor = 0x202020;

		fui = new h2d.Flow(s2d);
		fui.layout = Vertical;
		fui.verticalSpacing = 5;
		fui.padding = 10;

		var font = hxd.res.DefaultFont.get();

		RTC.init();

		pc = new RTCPeerConnection(["stun:stun.l.google.com:19302"], "0.0.0.0");

		ws = new WebSocket("ws://localhost:8080");
		ws.onmessage = (m) -> {
			switch (m) {
				case StrMessage(content):
					var conts = Json.parse(content);
					pc.setRemoteDescription(conts.sdp, conts.type);
				case _: {}
			}
		}

		var console = new h2d.Console(hxd.res.DefaultFont.get(), s2d);
		h2d.Console.HIDE_LOG_TIMEOUT = 1e8; // Don't

		var candidates = [];

		pc.onLocalCandidate = (c) -> {
			if (c != "")
				candidates.push('a=${c}');
		}
		pc.onGatheringStateChange = (s) -> {
			if (s == RTC_GATHERING_COMPLETE) {
				var sdpObj = StringTools.trim(pc.localDescription);
				sdpObj = sdpObj + '\r\n' + candidates.join('\r\n');
				ws.send(Json.stringify({
					type: "connect",
					sdpObj: {
						sdp: sdpObj,
						type: dc != null ? "offer" : "answer"
					}
				}));
			}
		}

		var conStatus = addText("Connection Status: Not Connected");

		pc.onDataChannel = (c) -> {
			dc = c;
			dc.onOpen = (l) -> {
				conStatus.text = "Connection Status: Connected";
			}
			dc.onMessage = (m) -> {
				console.log(' >> ' + m.toString());
			}
		}

		var connectBtn = addButton("Connect", () -> {
			dc = pc.createDatachannel("test");
			dc.onOpen = (l) -> {
				conStatus.text = "Connection Status: Connected";
			}
			dc.onMessage = (m) -> {
				console.log(' >> ' + m.toString());
			}
		});

		var input = new h2d.TextInput(hxd.res.DefaultFont.get(), s2d);
		input.backgroundColor = 0x80808080;
		input.y = this.s2d.height - 30;
		input.maxWidth = this.s2d.width;
		input.text = "Send message";
		input.onKeyDown = (e) -> {
			if (e.keyCode == Key.ENTER) {
				if (dc != null) {
					dc.sendMessage(input.text);
					console.log(' << ' + input.text);
				}
				input.text = "";
			}
		}
		input.onFocus = function(_) {
			input.textColor = 0xFFFFFF;
		}
		input.onFocusLost = function(_) {
			input.textColor = 0xAAAAAA;
		}
	}

	override function update(dt:Float) {
		super.update(dt);
		RTC.processEvents();
	}

	override function dispose() {
		RTC.finalize();
		super.dispose();
	}

	static function main() {
		new Main();
	}
}
