# Pattern-radio

An interactive web-radio based on [Pattern-game](https://github.com/tarmoj/patterngame),  written in Qt C++ using Csound API for sound generation.

##WHAT

Pattern-radio is a system for an interactive web-based collaborative sound stream creation - everybody can make a small melody and send it to the server to play. All melodies are repeated again and again in turn.

The server changes the sounds and relative durations of the notes for greater variety after every now and then.
The general tempo of the playback depends on the heart rate of one person wearing a pulse sensor that sends the current heart rate to the server in real time. 

Pattern-radio was created by Tarmo Johannes for festival ["Days of Estonian Music" 2015](http://www.eestimuusikapaevad.ee/en/), it ran approximately for a week and climaxed at T. Johannes's recital [PASSAGGIO](http://kultuur.info/blogi/en/2015/04/20/heather-stebbins-passagio-space-sound-and-persistence/), Estonian Music Days 2015, **Thu 16.04.15 at 7pm, Salme Cultural Centre**.

##WHY

It is an attempt to connect people - to provide an extremely simple interface where absolutely everybody is capable of creating his/her own small melody and commit to bigger body of collaborative music making. Everybody is connected through a computer based system but are also in connection with human element - the heart (the one which in the original version the people were going to meet in the concert). The goal of this sound game is not so much creating musically valuable result as the action and thoughts of people it hopes to trigger.

##HOW

(Concise technical description how it works.)

###Server

The core of the application is program pattern-server. It is a command line program (ie wihtout user interface) that can run in any Unix based server that has necessary dependencies installed (Qt, Csound, Jack, Icecast, Darkice). It is written in Qt C++.

The program runs websocket server and udp listener, keeps track of the pattern queues and looks after the sound generation. 

The **websocket server** class is used for receiving user messages (new patterns), storing them in log and organizing the pattern queues for high, low and medium voice. It takes also care for sending feedback (queus, currently playing patterns etc) to all connected clients (people having page monitor.html open) so they can see what is going on.

The **UDP listener** is used for receiving messages from the heart-rate app running in a phone that the "heart-person" is wearing. The source of the app is not included in this repository.



###Sound generation

All sound is generated in real time. The class CsEngine in the program uses **Csound API** to communicate with [Csound](http://csound.github.io) process that is responsible for making the sound. The csound file used is *patterngame-changetempo.csd*.

When a voice (high/low/medium) is free to play, it sets a value in specific channel that the main program can read. Then the main program takes first pattern in the queue and starts a Csound instrument that plays it and repeats given number of times.

For bigger variety, Csound changes the sounds and relative durations of the notes randomly. For now, user has no control over it.

The sound is outputted to [Jack](http://www.jackaudio.org/) sound server that seemed most convenient for further streaming.


###Streaming

The streaming is done using [IceCast](http://icecast.org/) streaming server. The connection between jack and icecast is created with program [DarkIce](http://www.darkice.org/). See the configuration files *darkice-jack.cfg* and *icecast.xml* in the source root to see how they were configured. The stream is in mp3 format and thus usable by almost everything form web browsers to special multimedia players.

Icecast is very stable but due many buffers it creates quite big latency - the user hears the sound at least 5 seconds (but most likely 10..20s) later than is played in the server.

To ease the start-up of all components, script  **start-streaming.sh** launches jack, pattern-radio main program, darkice and creates necessary jack connections. The icecast server must run before (good to configure the operationg system to start it at boot time). To stop them, use script **kill-streaming.sh**


###User interface and communication

There are two web pages for users: *radio.html* for creating new melodies, trying them out and sending to server and *monitor.html* for having a look which patterns are currently playing, which are in the queue, what is the current heart-rate, if available. Both pages have link also to the audio stream.

The pages are written in **html5 and javascript, WebAudio** for local sound production (trying out the melodies) and **websockets** to communicate with the server. They must be run in a browser that supports html5 and webaudio.


##WHO 

The software is written by Tarmo Johannes

trmjhnns @@@ gmail . com

http://tarmo.uuu.ee

http://github.com/tarmoj

http://emic.ee/tarmo-johannes

