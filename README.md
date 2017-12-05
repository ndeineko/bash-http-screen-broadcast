Create a small HTTP server to broadcast screen and sound from Linux in bash.

## Prerequisites

* A recent `bash` version
* [`ffmpeg`](https://ffmpeg.org/about.html) with x11grab+alsa input devices and libx264+aac codecs
* [`ncat`](https://nmap.org/ncat/) (or [`socat`](http://www.dest-unreach.org/socat/) or [`tcpserver`](http://cr.yp.to/ucspi-tcp/tcpserver.html) or [`socket`](http://manpages.ubuntu.com/manpages/trusty/man1/socket.1.html))
* (optional) `pavucontrol`
* (client) A web browser which support [Media Source Extensions](https://w3c.github.io/media-source/) with h264 and aac codecs

## Usage

* Start `screencapture.sh` with or without options
  * Example : `./screencapture.sh -v --port 1234 --videoscale 0.75`
* (optional) Open `pavucontrol`, go to "Recording" tab, find ffmpeg and set audio capture to "Monitor of ..."
* Find computer IP.
* (client) Open `http://IP:PORT/` in a browser
* To stop `screencapture.sh`, press `CTRL+C` in the terminal window or send a SIGINT to the process

## Options

If an option is not provided, a default value will be used.
```
    --port port                  Valid source port number for HTTP server
    --displayname name           Display name in the form hostname:displaynumber.screennumber
    --captureorigin position     Capture origin in the form X,Y (e.g. 208,254)
    --capturesize dimensions     Capture size in the form WxH (e.g. 640x480)
    --soundserver name           Sound server to use ("alsa", "pulse", "oss", ...)
    --audiodevice device         Audio input device
    --audiodelay seconds         Sound delay in seconds (e.g. 0.22)
    --videoscale scale           Output image scale factor (e.g. 0.75)
    --targetbitrate size         Output video target bitrate (e.g. 3M)
    --maxbitrate size            Output video maximum bitrate (e.g. 4M)
    --buffersize size            Video bitrate controler buffer size (e.g. 8M)
    --maxsegments number         Maximum amount of old files kept for each stream (audio and video)
-v, --verbose                    Show ffmpeg's verbose output
```
