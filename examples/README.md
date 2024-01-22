# Examples
The provided examples showcase connection and datachannels between two peers through Websocket signaling (requires [hxWebSockets](https://github.com/ianharrigan/hxWebSockets)).

## Copy-Paste
Console / Web Browser based program showcasing browser-native connection. One peer should be the offerer and the other should be the answerer. Copy the SDP from the offerer to the answerer and submit the answerer's SDP back to the offerer to establish the connection.

## Heaps
A small 2 peer chat application built on Heaps. Start the signaling server and run two instances of the program (either on Web or Hashlink). Then press the connect button to establish connection and after that you can send and receive messages.