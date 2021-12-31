# screencapture.sh

Bash script that creates a small HTTP server to broadcast screen and sound from Linux.

## Prerequisites

* Recent `bash` version
* [`ffmpeg`](https://ffmpeg.org/about.html) with x11grab+alsa input devices and libx264+aac codecs
* [`ncat`](https://nmap.org/ncat/) (or [`socat`](http://www.dest-unreach.org/socat/) or [`tcpserver`](http://cr.yp.to/ucspi-tcp/tcpserver.html) or [`socket`](http://manpages.ubuntu.com/manpages/trusty/man1/socket.1.html))
* (optionally) `pavucontrol`
* On the client side: web browser which supports [Media Source Extensions](https://w3c.github.io/media-source/) with h264 and aac codecs

## Usage

* Start `screencapture.sh` with or without options
  * Example : `./screencapture.sh -v --port 1234 --videoscale 0.75`
* (optionally) Open `pavucontrol`, go to `Recording` tab, find the line with ffmpeg and set audio capture to `Monitor of [...]`
* On the client side, open `http://IP:PORT/` in a web browser, where `IP` is the server IP and `PORT` is the default server port (8080) or the port specified using the appropriate command-line option
* To stop `screencapture.sh`, press `CTRL+C` in the terminal window or send a `SIGINT` to the process

## Options

Default values are used for parameters that are not specified via command-line options.
```
-p, --port port                  Valid source port number for HTTP server
-n, --displayname name           Display name in the form hostname:displaynumber.screennumber
-o, --captureorigin position     Capture origin in the form X,Y (e.g. 208,254)
-c, --capturesize dimensions     Capture size in the form WxH (e.g. 640x480)
-s, --soundserver name           Sound server to use ("alsa", "pulse", "oss", ...)
-a, --audiodevice device         Audio input device
-d, --audiodelay seconds         Sound delay in seconds (e.g. 0.22)
-e, --videoscale scale           Output image scale factor (e.g. 0.75)
-f, --framerate number           Output video frames per second (whole number)
-b, --targetbitrate size         Output video target bitrate (e.g. 3M)
-m, --maxbitrate size            Output video maximum bitrate (e.g. 4M)
-B, --buffersize size            Video bitrate controler buffer size (e.g. 8M)
-D, --segmentduration seconds    Duration of each segment file (in whole seconds)
-M, --maxsegments number         Maximum amount of old files kept for each stream (audio and video)
-t, --tempdir directory          Custom directory for temporary files
-v, --verbose                    Show ffmpeg's verbose output
-?, --help                       Print this help
```
