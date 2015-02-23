<CsoundSynthesizer>
<CsOptions>
-d
-odac:system:playback_ -+rtaudio=jack 
</CsOptions>
<CsInstruments>

sr = 44100
nchnls = 2
0dbfs = 1
ksmps = 32

#define MAXREPETITIONS  #5#

;GLOBALS: 
gkPseudoSlendro[] fillarray  1, 8/7, 4/3,   14/9,  16/9, 2
gkPelogHarrison[]  fillarray 1, 35/32, 5/4, 21/16, 49/32, 105/64, 7/4, 2

gkBohlenJust[]  fillarray 1, 25/21, 9/7, 7/5, 5/3, 9/5, 15/7, 7/3, 25/9, 3/1 

gkSteps[] init 16
gkSteps  = gkPseudoSlendro ;gkBohlenJust ;gkPelogHarrison; 
gkTempo init 1
giBaseFrequency = 110 ;cpspch(5.02)

giPatternLength = 6;7 ; check taht would be same as in html interface
gimaxPitches  lenarray  gkSteps

gkSquareDuration[] fillarray 0.25, 0.25, 0.25
gkClock[] init 3
giPan[] fillarray 0.5, 1, 0
gkSoundType[] init 3


giMatrix[][]  init   3,giPatternLength  ; first dimension - voice, second: step or -1
;giMatrix[]  init   giPatternLength   ; table to contain which step from scale to play. -1 for don't play  0 - 1st step etc


gaSignal[] init 3

gkFreeToPlay[] init 3 ; flags the show if the voice is playing

;CHANNELS:
chn_k "heartrate",1
chn_k "free1",3


chnset 1,"tempo"
chnset 0.5, "level"
chnset 1, "free1"
chnset 1, "free2"
chnset 1, "free3"
chnset 0.25, "square1"
chnset 0.25, "square2"
chnset 0.25, "square3"

;

seed 0

; to test:



;gkSquareDuration[0] init 2
;gkSquareDuration[1] init 1
;gkSquareDuration[2] init 0.4

;schedule "randomPattern", 0, 0, 0, 1
;schedule "randomPattern", 1, 0, 1, 1
;schedule "randomPattern", 2.1, 0, 2, 1 ; last 1 if to repeat

 ;alwayson "randomStarter"
instr randomStarter
	kfree1 init 0
	kfree1 chnget "free1"
	printk2 kfree1
	if (changed(kfree1)==1 && kfree1==1) then
		kfree1 =0 
		chnset 0, "free1"	
		event "i", "randomPattern",0,0,0
	endif	
endin

instr randomPattern
	index = 0
	ivoice = p4
	;iloop = p5
	
loophere:
	giMatrix[ivoice][index] = limit(int(random:i(-gimaxPitches/2,gimaxPitches)), -1, gimaxPitches)
	
	;print index, giMatrix[ivoice][index]
	loop_lt index, 1, giPatternLength, loophere
	
	schedule "playPattern",0,1,  int(random:i(0,4)), int(random:i(2,8)), ivoice
	;if (iloop>0) then
;		schedule	"randomPattern", (giPatternLength+1)*i(gkSquareDuration[ivoice]), 0, ivoice, iloop
;	endif
endin

; gkTempo init 1.5
alwayson "clockAndChannels"
instr clockAndChannels 
	
	;gkTempo chnget "tempo" ; 1 - normal, <1 - slower, >1 - faster
	gkLevel chnget "level"
	
	gkTempo = 1;1+chnget:k("heartrate")/60 ; 1- neutral, <1 - slower >1 - faster
	;printk2 gkTempo
	
	gkSoundType[0] chnget "sound1" 
	gkSoundType[1] chnget "sound2"
	gkSoundType[2] chnget "sound3"
	
	if (metro(2)==1) then ; allow square duration changes only "on tick"	
		gkSquareDuration[0] chnget "square1"
		gkSquareDuration[1] chnget "square2"
		gkSquareDuration[2] chnget "square3"
	endif	
	
	; to sync incoming messages:		
	gkClock[0] metro gkTempo/gkSquareDuration[0]
	gkClock[1] metro gkTempo/gkSquareDuration[1]
	gkClock[2] metro gkTempo/gkSquareDuration[2]
	
endin

schedule "playPattern",0, 0,0,5,0
instr playPattern
	itimes = p4 ; how many times to repeat: 1 means original + 1 repetition
	irepeatAfter = p5 ; repeat after given squareDurations
	ivoice = p6 ; three voices
	ipanOrSpeaker = (p7==0) ? int(random:i(1,7)) : p7; number of speaker if 8 channels, otherwise expresse pan 1-left, 8- right; TODO - muuda
	ivisit = p8 ; 0 when original, 1 when first repetition etc
	;itotalTime = giPatternLength*i(gkSquareDuration[ivoice]) + itimes*irepeatAfter*i(gkSquareDuration[ivoice])+1
	p3 = giPatternLength * i(gkSquareDuration[ivoice])*2 ; for any case, when tempo get much slower
	print ivoice, ivisit, itimes, irepeatAfter
	
	Schannel sprintf "free%d",ivoice+1
	chnset 0, Schannel ; not free any more
	
	;index = 0
	;schedule "loopPlay", 0, itotalTime,  itimes, irepeatAfter, ivoice  
	; play sounds on clock's ticks to bea able to change tempo
	kcounter init 0
	if (gkClock[ivoice]==1 && kcounter<giPatternLength) then		
		if (itimes>0 && ivisit<=itimes && kcounter==irepeatAfter-1) then ; for repetition call itself
			event "i", p1,0, 10,p4,p5,p6,p7, ivisit+1		
		endif
		kstep = giMatrix[ivoice][kcounter] 
		if (kstep > -1) then
			;printk2 kstep 
			
			kfreq = (1<<ivoice)*giBaseFrequency*gkSteps[limit:k(kstep,0, giPatternLength-1) ] ; index out of range in some reason...
			;printk2 kfreq
			;print istep,ifreq
			;TODO: make amp lesser for every next repetition
			event "i","sound", 0, gkSquareDuration[ivoice], 0.2*ampdbfs(-6*ivisit) ,kfreq , ivoice 
		endif
		kcounter += 1
		;printk2 kcounter
	endif
	
	if (gkClock[ivoice]==1 && kcounter==giPatternLength && ivisit==itimes) then
		event "i", "setFree", 2*gkSquareDuration[ivoice], 0.1, ivoice ; signal for free after 2 scuares in given tempo
		turnoff	
	endif			
endin

instr setFree ; sets flag that signals host to send new pattern
	ivoice = p4
	Schannel sprintf "free%d",ivoice+1
	chnset 1, Schannel
endin

; schedule "sound", 0,  0.25, 0.1, 440
instr sound
	iamp = p4
	ifreq =  p5
	ivoice = p6
	iatt = 0.05
	;aenv expseg 0.0001, iatt, 1, p3-iatt, 0.0001
	aenv adsr 0.01,0.01,1, p3/2
	; TODO: proovi adsr
	isound = i(gkSoundType[ivoice]) ;chnget "sound"
	if (isound==0) then 
		asig poscil 1,ifreq ;,giSine
		asig chebyshevpoly asig, 0, 1, rnd(0.2), rnd(0.1),rnd(0.1), rnd(0.1), rnd(0.05), rnd(0.03) ; add some random timbre
	elseif (isound==1) then
		;kcx     line    0.1, p3, 1; max -15 ... 15
		;krx line 0.1,p3, 0.5
		kcx   init random:i(0.1,0.5);  line    0, p3, 0.2
		krx     linseg  0.1, p3/2, random:i(0.2,0.6), p3/2, 0.1
		awterr      wterrain    1, ifreq,kcx, 0, krx/2, krx, -1, -1
		asig      dcblock awterr ; DC blocking filter
	elseif (isound==3) then 
		asig fmbell	1, ifreq,random:i(0.8,2), random:i(0.5,1.1),0.005,4
	
	elseif (isound==2) then	
		asig vco2 1, ifreq
		asig moogladder asig, line(ifreq*(1+rnd(6)),p3,ifreq*(2+rnd(2))), 0.8
	elseif (isound==4) then	
		ix random 4,10
		kcx   line -ix,p3,ix 
		krx line random:i(0.1,4) ,p3, random:i(0.1,4)
		awterr      wterrain    1, ifreq,kcx, 0, krx/2, krx, -1, -1
		asig      dcblock awterr ; DC blocking filte
		asig butterlp asig,2000
	else
		asig pinker
		asig moogvcf asig, line(ifreq*(1+rnd(6)),p3,ifreq*(2+rnd(2))), random:i(0.5,0.9)
	endif
	
	asig = asig*iamp*aenv
	outs asig, asig	
	
	;gaSignal[ivoice] = gaSignal[ivoice] + asig
endin





</CsInstruments>
<CsScore>

</CsScore>
</CsoundSynthesizer>
<bsbPanel>
 <label>Widgets</label>
 <objectName/>
 <x>0</x>
 <y>0</y>
 <width>394</width>
 <height>402</height>
 <visible>true</visible>
 <uuid/>
 <bgcolor mode="nobackground">
  <r>255</r>
  <g>255</g>
  <b>255</b>
 </bgcolor>
 <bsbObject type="BSBButton" version="2">
  <objectName>play pattern</objectName>
  <x>17</x>
  <y>72</y>
  <width>137</width>
  <height>30</height>
  <uuid>{fd46780e-b7e0-4087-9b8b-311012e6066d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>pattern 1</text>
  <image>/</image>
  <eventLine>i "randomPattern" 0 1 0 0</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>free1</objectName>
  <x>78</x>
  <y>194</y>
  <width>80</width>
  <height>25</height>
  <uuid>{77252a9a-278b-4382-a4b5-d989407aacc6}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>1.000</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBButton" version="2">
  <objectName>play pattern</objectName>
  <x>19</x>
  <y>107</y>
  <width>137</width>
  <height>30</height>
  <uuid>{56e42de5-2a60-4e81-99a8-2eb0d06ce627}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>pattern 2</text>
  <image>/</image>
  <eventLine>i "randomPattern" 0 1 1 0</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject type="BSBButton" version="2">
  <objectName>play pattern</objectName>
  <x>19</x>
  <y>143</y>
  <width>137</width>
  <height>30</height>
  <uuid>{63b8b219-1259-49b7-a398-aa909950b935}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <type>event</type>
  <pressedValue>1.00000000</pressedValue>
  <stringvalue/>
  <text>pattern 3</text>
  <image>/</image>
  <eventLine>i "randomPattern" 0 1 2 0</eventLine>
  <latch>false</latch>
  <latched>true</latched>
 </bsbObject>
 <bsbObject type="BSBSpinBox" version="2">
  <objectName>sound1</objectName>
  <x>39</x>
  <y>292</y>
  <width>80</width>
  <height>25</height>
  <uuid>{8a4b41b7-ef02-4ab1-95f0-817710599202}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <resolution>1.00000000</resolution>
  <minimum>0</minimum>
  <maximum>2</maximum>
  <randomizable group="0">false</randomizable>
  <value>1</value>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>meditation</objectName>
  <x>260</x>
  <y>108</y>
  <width>108</width>
  <height>30</height>
  <uuid>{ceaf72bd-ea45-4832-a6f5-28fb9834d99d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.12962963</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>173</x>
  <y>110</y>
  <width>80</width>
  <height>26</height>
  <uuid>{d4bddaac-f239-47cd-8fba-8fde41a73fcd}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Meditation</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>attention</objectName>
  <x>263</x>
  <y>145</y>
  <width>108</width>
  <height>30</height>
  <uuid>{53512250-33af-4df4-badb-1d7d657537e8}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.75925926</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>172</x>
  <y>145</y>
  <width>80</width>
  <height>26</height>
  <uuid>{c28ebf97-4c5a-496b-8c26-9530354bae4d}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Attention</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>lowBetaRelative</objectName>
  <x>264</x>
  <y>178</y>
  <width>108</width>
  <height>30</height>
  <uuid>{29189bb2-45ed-4c6c-ad46-00ee2c064799}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.07407407</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>172</x>
  <y>181</y>
  <width>80</width>
  <height>26</height>
  <uuid>{f95640a2-4be1-4c9d-a0d9-06dbfd7cf31b}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Lowbeta</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>highBetaRelative</objectName>
  <x>263</x>
  <y>219</y>
  <width>108</width>
  <height>30</height>
  <uuid>{9b3079ab-97b1-46e9-bb31-6271b2862802}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>0.00000000</minimum>
  <maximum>1.00000000</maximum>
  <value>0.77777778</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>172</x>
  <y>220</y>
  <width>80</width>
  <height>26</height>
  <uuid>{144456d7-768a-4ade-a4fa-af24c7fdc857}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Highbeta</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBHSlider" version="2">
  <objectName>heartrate</objectName>
  <x>183</x>
  <y>365</y>
  <width>117</width>
  <height>37</height>
  <uuid>{8c8518b1-3689-4914-87cf-1c0d9cee5078}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <minimum>40.00000000</minimum>
  <maximum>120.00000000</maximum>
  <value>52.30769231</value>
  <mode>lin</mode>
  <mouseControl act="jump">continuous</mouseControl>
  <resolution>-1.00000000</resolution>
  <randomizable group="0">false</randomizable>
 </bsbObject>
 <bsbObject type="BSBLabel" version="2">
  <objectName/>
  <x>79</x>
  <y>371</y>
  <width>80</width>
  <height>25</height>
  <uuid>{6b1bb637-24c0-433d-bc43-c8286b262238}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>Heartrate
</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>noborder</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
 <bsbObject type="BSBDisplay" version="2">
  <objectName>heartrate</objectName>
  <x>314</x>
  <y>371</y>
  <width>80</width>
  <height>25</height>
  <uuid>{1c28c67f-193e-4c4e-b557-de53d6537463}</uuid>
  <visible>true</visible>
  <midichan>0</midichan>
  <midicc>0</midicc>
  <label>52.308</label>
  <alignment>left</alignment>
  <font>Liberation Sans</font>
  <fontsize>10</fontsize>
  <precision>3</precision>
  <color>
   <r>0</r>
   <g>0</g>
   <b>0</b>
  </color>
  <bgcolor mode="nobackground">
   <r>255</r>
   <g>255</g>
   <b>255</b>
  </bgcolor>
  <bordermode>border</bordermode>
  <borderradius>1</borderradius>
  <borderwidth>1</borderwidth>
 </bsbObject>
</bsbPanel>
<bsbPresets>
</bsbPresets>