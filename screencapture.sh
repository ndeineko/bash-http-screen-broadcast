#!/bin/bash
#
# USAGE: screencapture.sh [-v]
# DESCRIPTION: Capture screen and audio with ffmpeg and share it via a very primitive HTTP server.
# OPTIONS: '-v' : Show verbose ffmpeg output
#

### Settings:

PORT="8080" # Http server port

DISPLAYNAME=":0.0" # Screen identifier
CAPTUREPOSITION="0,0" # Capture origin X,Y
CAPTURESIZE="1366x768" # Capture size WxH

SOUNDSERVER="alsa"
AUDIODEVICE="default"
AUDIODELAY="0.16" # in seconds

VIDEOSCALE="0.5" # Output image scale factor

TARGETBITRATE="4.5M" # Ouput video target bitrate
MAXBITRATE="6M" # Output video maximum bitrate
BUFFERSIZE="12M" # Bitrate controler buffer size

MAXSEGMENTS="4" # Maximum number of old files kept for each stream (audio or video)

### End of settings

startCapture(){
	echo -n "\"use strict\";var mimeCodec=[\"video/mp4; codecs=\\\"avc1.42c01f\\\"\",\"audio/mp4; codecs=\\\"mp4a.40.2\\\"\"],segmentDuration=2;" > metadata.js

	mkdir 0 1

	ffmpeg \
		-loglevel "$LOGLEVEL" \
		-f x11grab -s:size "$CAPTURESIZE" -thread_queue_size 64 -i "$DISPLAYNAME+$CAPTUREPOSITION" \
		-f "$SOUNDSERVER" -thread_queue_size 1024 -itsoffset "$AUDIODELAY" -i "$AUDIODEVICE" \
		-pix_fmt yuv420p \
		-filter:a "aresample=first_pts=0" \
		-c:a aac -strict experimental -b:a 128k -ar 48000 \
		-filter:v "scale=trunc(iw*$VIDEOSCALE/2)*2:trunc(ih*$VIDEOSCALE/2)*2" \
		-c:v libx264 -profile:v baseline -tune fastdecode -preset ultrafast -b:v "$TARGETBITRATE" -maxrate "$MAXBITRATE" -bufsize "$BUFFERSIZE" -r 30 -g 60 -keyint_min 60 \
		-movflags +empty_moov+frag_keyframe+default_base_moof+cgop \
		-f dash -min_seg_duration 2000000 -use_template 0 -window_size "$MAXSEGMENTS" -extra_window_size 0 -remove_at_exit 1 -init_seg_name "\$RepresentationID\$/0" -media_seg_name "\$RepresentationID\$/\$Number\$" manifest.mpd
}

if [ "$1" == "-v" ]
then
	LOGLEVEL="verbose"
elif [ "$1" == "" ]
then
	LOGLEVEL="quiet"
else
	echo "Invalid option:  $1"
	exit 1
fi

tempdir=$(mktemp --directory --suffix=ffmpeg-screen-capture)

trap "rm --recursive --force \"$tempdir\"" INT EXIT

cd "$tempdir"

startCapture&

cat >server.sh <<-"EOFF"
	#!/bin/bash

	read -r -d "" HTML <<-"EOF"
	<!DOCTYPE html>
	<html>
	<head>
		<meta charset="UTF-8">
		<title>Screen</title>
		<style>
			body{
				margin:0;
				overflow:hidden;
				background:#000;
			}
			video{
				height:100vh;
				width:100vw;
			}
		</style>
		<script src="/metadata.js"></script>
		<script>
			"use strict";

			var nextId = [];
			var sourceBuffer = [];
			var httpRequest = [];
			var queuedAppend = [];
			var mediaSource;
			var videoElement;

			// restarts all streams at nextSegment
			function abortAndRestart(nextSegment) {
				for(var i = 0; i < mimeCodec.length; i++) {
					sourceBuffer[i].abort();
					
					if(httpRequest[i] != null) {
						httpRequest[i].abort();
						httpRequest[i] = null;
					}
					
					nextId[i] = nextSegment;
					
					var sb = sourceBuffer[i];
					sb.timestampOffset = -segmentDuration * (nextSegment - 1);
					if(sb.buffered.length > 0) {
						sb.remove(0, sb.buffered.end(sb.buffered.length - 1));
					}
					else {
						fetchNext(i);
					}
				}
			}

			function getArrayBuffer(url, callback) {
				var xhr = new XMLHttpRequest();
				xhr.addEventListener("load", function() {
					if(xhr.status == 404) {
						var nextSegment = parseInt(xhr.getResponseHeader("Next-Segment"));
						abortAndRestart(nextSegment);
					}
					else {
						callback(xhr.response);
					}
				}, false);
				xhr.open("GET", url);
				xhr.responseType = "arraybuffer";
				xhr.send();
				return xhr;
			}

			// add ArrayBuffer buf to sourceBuffer[i]
			function sourceBufferAppend(i, buf) {
				var sb = sourceBuffer[i];
				
				try {
					sb.appendBuffer(buf);
				}
				catch(e) { // QuotaExceededError
					if(sb.buffered.length > 0) {
						var start = sb.buffered.start(0);
						var end = sb.buffered.end(sb.buffered.length - 1);

						queuedAppend[i] = buf;
						
						sb.remove(start, (start + end) / 2); // remove old frames that were not automatically evicted by the browser
					}
					else {
						var max = 0;
						for(var i = 0; i < nextId.length; i++) {
							if(max < nextId[i]) {
								max = nextId[i];
							}
						}
						abortAndRestart(max);
					}
				}
			}

			// set currentTime to a valid position and play video
			function tryToPlayAndAjustTime() {
				if(videoElement.buffered.length > 0) {					
					var start = videoElement.buffered.start(videoElement.buffered.length - 1);

					if(videoElement.currentTime <= start) {
						videoElement.currentTime = start;
						if(videoElement.paused){
							videoElement.play();
						}
					}
					else {
						var end = videoElement.buffered.end(videoElement.buffered.length - 1);
						
						if(videoElement.currentTime > end) {
							videoElement.currentTime = end;
							if(videoElement.paused){
								videoElement.play();
							}
						}
					}
				}
			}

			function addUpdateendListener(i) {
				sourceBuffer[i].addEventListener("updateend", function() { // this is executed when the SourceBuffer.appendBuffer or SourceBuffer.remove has ended
					var ab = queuedAppend[i];
					if(ab == null) {
						fetchNext(i);
						tryToPlayAndAjustTime();
					}
					else { // previous append failed in sourceBufferAppend(i, buf) and needs to be added again
						queuedAppend[i] = null;
						sourceBufferAppend(i, ab);
					}
				}, false);
			}

			function fetchNext(streamId) {
				httpRequest[streamId] = getArrayBuffer("/" + streamId + "/" + nextId[streamId], function(buf) {
					httpRequest[streamId] = null;
					nextId[streamId]++;
					sourceBufferAppend(streamId, buf);
				});
			}

			window.addEventListener("load", function() {
				if(!("MediaSource" in window)) {
					alert("MediaSource API not supported.");
				}
				else {
					for(var i = 0; i < mimeCodec.length; i++) {
						if(!MediaSource.isTypeSupported(mimeCodec[i])) {
							alert("Unsupported media type or codec: " + mimeCodec[i]);
						}
						nextId.push(0);
						sourceBuffer.push(null);
						httpRequest.push(null);
						queuedAppend.push(null);
					}

					mediaSource = new MediaSource();
					mediaSource.addEventListener("sourceopen", function() {
						for(var i = 0; i < mimeCodec.length; i++) {
							sourceBuffer[i] = mediaSource.addSourceBuffer(mimeCodec[i]);

							if(!sourceBuffer[i].updating) {
								fetchNext(i);
							}
							
							addUpdateendListener(i);
						}
					}, false);

					videoElement = document.querySelector("video#v");
					videoElement.src = URL.createObjectURL(mediaSource);

					videoElement.addEventListener("click", function(e) {
						if(videoElement.paused) {
							videoElement.play();
						}
						else {
							videoElement.pause();
						}
						e.preventDefault();
					}, false);
				}
			}, false);
		</script>
	</head>
	<body>
		<video id="v"></video>
	</body>
	</html>
	EOF

	HTMLSIZE="${#HTML}"

	CR=$(echo -ne "\r")

	getLastSegmentId(){
		if [ -f "0/0" ]
		then
			ls -1t "0/"|grep --extended-regexp --max-count=1 "^[0-9]+$"
		else
			echo -n 0
		fi
	}

	printOtherHeaders(){
		echo -ne "Connection: keep-alive\r\nCache-Control: no-cache, no-store, must-revalidate\r\nPragma: no-cache\r\nExpires: 0\r\nServer: screencapture\r\n\r\n"
	}

	printHeaders200(){
		echo -ne "HTTP/1.1 200 OK\r\nContent-Type: $1\r\nContent-Length: $2\r\n"
		printOtherHeaders
	}

	printHeaders404(){
		echo -ne "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nNext-Segment: $(getLastSegmentId)\r\n"
		printOtherHeaders
	}

	printMetaData(){
		printHeaders200 text/javascript $(stat --printf="%s" metadata.js)
		cat metadata.js
	}

	printHTML(){
		printHeaders200 text/html "$HTMLSIZE"
		echo -n "$HTML"
	}

	sleepABit(){
		if type usleep >/dev/null 2>&1
		then
			usleep 200000
		else
			sleep 0.2
		fi
	}

	waitFileExistence(){
		until [ -f "$1" ]
		do
			sleepABit
		done
	}

	waitFileNotEmpty(){
		while [ "$(stat --printf="%s" "$1" 2>/dev/null)" == "0" ]
		do
			sleepABit
		done
	}

	printSegmentResponse(){
		segmentId=$(echo -n "$1"|cut -d "/" -f 2)
		
		if [ "$segmentId" == "0" ]
		then
			waitFileExistence "$1"
			waitFileNotEmpty "$1"
		elif [ ! -f "$1" ]
		then
			lastSegmentId=$(getLastSegmentId)
			
			if [ "$segmentId" -gt "$lastSegmentId" ]
			then
				waitFileExistence "$1"
			else
				printHeaders404
				return
			fi
		fi
		
		size=$(stat --printf="%s" "$1" 2>/dev/null)

		if [ "$?" == "0" ]
		then
			{
				exec 3<"$1"
			} 2>/dev/null
			
			if [ "$?" == "0" ]
			then
				printHeaders200 application/octet-stream "$size"
				cat <&3
				exec 3<&-
			else
				printHeaders404
			fi
		else
			printHeaders404
		fi
	}

	while read -r line
	do
		if echo -n "$line"|grep --extended-regexp --quiet "^GET\s.+\sHTTP/1\.[01]$CR?$"
		then
			if echo -n "$line"|grep --extended-regexp --quiet "^GET\s/[0-9]+/[0-9]+\s"
			then
				printSegmentResponse "$(echo -n "$line"|grep --extended-regexp --only-matching "[0-9]+/[0-9]+")"
			elif echo -n "$line"|grep --extended-regexp --quiet "^GET\s/\s"
			then
				printHTML
			elif echo -n "$line"|grep --extended-regexp --quiet "^GET\s/metadata\.js\s"
			then
				printMetaData
			else
				printHeaders404
			fi
		fi
	done
EOFF

chmod +x server.sh

if type ncat >/dev/null 2>&1
then
	ncat --listen --keep-open --source-port "$PORT" --exec ./server.sh
elif type socat >/dev/null 2>&1
then
	socat TCP-LISTEN:"$PORT",fork EXEC:./server.sh
elif type tcpserver >/dev/null 2>&1
then
	tcpserver 0.0.0.0 "$PORT" ./server.sh
elif type socket >/dev/null 2>&1
then
	socket -f -p ./server.sh -s -l "$PORT"
else
	echo "None of those TCP/IP swiss army knives installed on this system: ncat, socat, tcpserver, socket" >&2
	exit 1
fi
