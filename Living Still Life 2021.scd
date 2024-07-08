

  //--------------------------------------------------------//
 //   connect to the already-running remote belaserver     //
//--------------------------------------------------------//

(
Server.default = s = Server("belaServer", NetAddr("bela.local", 57110));
s.options.maxLogins = 4; // should match the settings on the Bela
s.initTree;
s.startAliveThread;
);

// Communicate with the server
s.plotTree; // show all active nodes
s.freeAll;  // free all nodes

     //-----------------------------------------------------------------------//
    //  2-channel fm synth uses highest resonant frequency                   //
   //   as carrier freq and list of 20 000 next highest freqs               //
  //    for modulation frequency. This is flipped for channel 2.           //
 //     pattern uses random values for duration, amplitude and envelope.  //
//-----------------------------------------------------------------------//
(
~copper_pot_freqs = CSVFileReader.readInterpret(Platform.resourceDir +/+ "copper_freqs.csv", true).postcs;

SynthDef.new(\fm_copper_synth, {
	arg carHz=500, modHz=100, modAmp=200, del=0.2,
	atk=0.01, rel=1, amp=0.2, amp2=0.75, pan=0;
	var car, car1, car2, mod1, mod2, env;

	env = EnvGen.kr(Env.perc(atk, rel), doneAction:2);

	mod1 = SinOsc.ar(modHz, mul:modAmp);
	mod2 = SinOsc.ar(carHz, mul:modAmp);

	car1 = SinOsc.ar(carHz + mod1) * env * (amp);
	car2 = DelayL.ar((SinOsc.ar(modHz + mod2) * env * (amp2)), 0.2, del);

	//car = Pan2.ar(car, pan);
	[Out.ar(3, car1), Out.ar(5, car2)];
	//Out.ar(5, car2);
	}).add;

~copper_pattern = Pbind(
	\instrument, \fm_copper_synth,
	\dur, Pexprand(1/64, 4, inf),
	\amp, Pexprand(0.01, 0.61),
	\amp2, Pexprand(0.01, 0.61),
	\carHz, 1871,
	\modHz, Pxrand(~copper_pot_freqs, inf),
	\modAmp, Pwhite(2500, 10000),
	\amp, Pexprand(0.015, 0.15),
	\atk, Pexprand(0.0001, 0.005),
	\rel, Pexprand(0.5, 2.2),
	\del, Pexprand(0.001, 1.0),
	\type, Pwrand([\note, \rest], [0.25, 0.75], inf)
).play;
)
~copper_pattern.stop;
          //-------------------------------------------------------------------------//
         // 3 samples are loaded: a glass vase being bowed, pages from              //
        //  a book being leafed through, and an atmospheric synthesizer            //
       //   recording.                                                            //
      //                                                                         //
     //    4 synths based on BufRd are created. \bufrd_noise uses a             //
    //     noise generator to determine what point in the sample is            //
   //      played next. \bufrd_sine plays back the sample along a             //
  //       sine wave, while bufrd_tri does the same with a triangle wave.    //
 //        \bufrd plays the sample in order from beginning to end.          //
//-------------------------------------------------------------------------//
(
~glass = Buffer.read(s, "/usr/share/SuperCollider/sounds/bowedGlassMaster.wav");
~book = Buffer.read(s, "/usr/share/SuperCollider/sounds/bookpages.aif");
~table = Buffer.read(s, "/usr/share/SuperCollider/sounds/TableTopDrone.aif");

SynthDef.new(\bufrd_noise, {
	arg amp=1, out=0, buf, start=0, end, freq=1;
	var sig, ptr;
	ptr = LFDNoise1.ar(freq).range(start, end);
	sig = BufRd.ar(1, buf, ptr);
	sig = sig * amp;
	Out.ar(out, sig);
}).add;

SynthDef.new(\bufrd_sine, {
	arg amp=1, out=0, buf, start=0, end, freq=1, mix=0.5, room=0.3, damp=0.5;
	var sig, ptr;
	ptr = SinOscFB.ar(freq, 0.01).range(start, end);
	sig = BufRd.ar(1, buf, ptr);
	sig = sig * amp;
	Out.ar(out, FreeVerb.ar(sig, mix, room, damp));
}).add;

SynthDef.new(\bufrd_tri, {
	arg amp=1, out=0, buf, start=0, end, freq=1, mix=0.5, room=0.3, damp=0.5;
	var sig, ptr;
	ptr = LFTri.ar(freq, 0).range(start, end);
	sig = BufRd.ar(1, buf, ptr);
	sig = sig * amp;
	Out.ar(out, FreeVerb.ar(sig, mix, room, damp));
}).add;

SynthDef.new(\bufrd, {
	arg amp=1, out=0, buf;
	var sig, ptr;
	ptr = Line.ar(0, BufFrames.kr(buf) - 1, BufDur.kr(buf), doneAction:2);
	sig = BufRd.ar(2, buf, ptr);
	sig = sig * amp;
	Out.ar(out, sig);
}).add;
)

   //-----------------------------------------------------------------------//
  //  Create a synth each for the vase, book, and table.                   //
 //   Evaluate .set arguments to change the playback in realtime.         //
//-----------------------------------------------------------------------//

~glassSynth = Synth.new(\bufrd_sine, [\out, 0, \buf, ~glass.bufnum, \start, 0, \end, ~glass.numFrames - 1, \freq, 0.001]);

~bookSynth = Synth.new(\bufrd_noise, [\out, 1, \buf, ~book.bufnum, \start, 0, \end, ~book.numFrames - 1, \freq, 1, \amp, 1.5]);

~tableSynth = Synth.new(\bufrd_tri, [\out, 2, \buf, ~table.bufnum, \start, 0, \end, ~table.numFrames - 1])

~glassSynth.set(\freq, 0.01);
~glassSynth.set(\amp2, 0.4);
~glassSynth.free;
~bookSynth.set(\freq, 1.12);
~bookSynth.free;
~tableSynth.set(\freq, 0.0099);
~tableSynth.free;
~copper_pattern.stop;