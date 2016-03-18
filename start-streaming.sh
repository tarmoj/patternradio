jackd -P70 -d dummy -r44100 -p512 &
# jackd -t2000 -d dummy -r48000 -p1024 &
sleep 5
# csound OSC-recv1-andOSC.csd &
# check if icecast is running?
darkice -c /home/tarmo/tarmo/csound/patternradio/darkice-jack.cfg &
sleep 1
#csound test_orc.csd &
#csound test_orc_2inout.csd -m0 &
cd /home/tarmo/tarmo/csound/patternradio/build-patternradio-server-Qt5_desktop-Debug
./patternradio-server &
sleep 2
jack_connect csound6:output1 darkice:left && jack_connect csound6:output2 darkice:right

#cvlc -v 'jack://channels=2:ports=.*' --sout-keep --sout '#transcode{acodec=mpga,ab=128,channels=2,samplerate=44100}:std{access=mmsh,mux=asfh,dst=:8080}' &

# sleep 2
# php OSC-send1.php &
