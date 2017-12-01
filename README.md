Create a small HTTP server to broadcast screen and sound from a linux computer in bash.

## Prerequisites

* A recent `bash` version
* [`ffmpeg`](https://ffmpeg.org/about.html) with x11grab+alsa input devices and libx264+aac codecs
* [`ncat`](https://nmap.org/ncat/) (or [`socat`](http://www.dest-unreach.org/socat/) or [`tcpserver`](http://cr.yp.to/ucspi-tcp/tcpserver.html) or [`socket`](http://manpages.ubuntu.com/manpages/trusty/man1/socket.1.html))
* (optional) `pavucontrol`
* (client) A web browser which support [Media Source Extensions](https://w3c.github.io/media-source/) with h264 and aac codecs

## Configuration

* Clone this repository or download [screencapture.sh](https://github.com/ndeineko/bash-http-screen-broadcast/blob/master/screencapture.sh)
* `chmod +x screencapture.sh`
* Open it in a text editor and change settings (at the beginning of the file). Important ones are PORT, CAPTUREPOSITION, CAPTURESIZE, and VIDEOSCALE.

## Usage

* Execute `./screencapture.sh` (add `-v` to show ffmpeg's verbose output)
* (optional) Open `pavucontrol`, go to "Recording" tab, find ffmpeg and set audio capture to "Monitor of ..."
* Find computer IP.
* (client) Open `http://IP:PORT/` in a browser
