(
~amp = 0.3;//global amp factor applied to all sound sources, but not to effects, let we double apply it
Server.default.options.memSize = 25500000;//128000;
s.options.maxNodes = 2048 * 2 * 2;
s.reboot;
s.waitForBoot({
	fork {
		~play = {
			arg buff;
			{PlayBuf.ar(2,buff, BufRateScale.kr(buff)).madd(~amp)}.play;
		};
		// Globals
		~noteNamesSharp = ["c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"];
		~noteNamesFlat  = ["c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b"];

		~noteNameToMidi = { |name, octave|
			var n = name.toLower;  // normalize to lowercase
			var pc = (~noteNamesSharp.indexOfEqual(n) ?? { ~noteNamesFlat.indexOfEqual(n) });
			if (pc.isNil) {
				("Unknown note name: " ++ n).warn;
				^nil
			};

			(60 + pc + (12 * (octave - 4)));
		};

		// Global arrays
		~buffFreqs = Array.fill(4, { Array.new });
		~buffsInOrder = Array.new;

		~loadGlockBuffFreqs = { |sampleDirectory|
			var files = PathName(sampleDirectory).files.collect(_.fullPath).select({ |f|
				f.toLower.endsWith(".wav")
			}), minFreq = 20000, maxFreq = 0;

			files.do { |filePath|
				var filename = PathName(filePath).fileNameWithoutExtension;
				var parts = filename.split($_);
				var dyn, notePart, noteName, octave, midi, freq, buf;

				// last part = dynamic level
				dyn = parts.last.asInteger - 1;

				// second-to-last part = note+octave (e.g. c4, db5, etc.)
				notePart = parts[parts.size - 2];

				// octave = last char of notePart
				octave = notePart.last.asString.asInteger;

				// note name = everything except last char
				noteName = notePart.drop(-1).toLower;

				// compute MIDI + freq
				midi = ~noteNameToMidi.(noteName, octave);

				freq = 440 * (2 ** ((midi - 69) / 12.0));

				// load buffer
				buf = Buffer.read(s, filePath);

				// store
				~buffsInOrder.add([buf, freq]);
				if (dyn < 4 and: { dyn >= 0 }) {
					~buffFreqs[dyn].add([buf, freq]);
					minFreq = freq.min(minFreq);
					maxFreq = freq.max(maxFreq);
				} {
					("Warning: dyn " ++ dyn ++ " out of range for file: " ++ filename).warn;
				};
			};

			("Finished loading samples. Range : " ++ minFreq ++ " - " ++ maxFreq).postln;
		};

		~loadGlockBuffFreqs.(Document.current.dir ++"/dependencies/samples/glock_samples");

		~samples = [
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/oct01.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/oct12.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/harmFract1.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/keyBurst1.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/keyBurst2.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/keyBurst3.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/keyBurst4.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/low_murmery_burst1.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/harmFract2.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/harmFract3.wav")
		];

		~harmonicFractals = Array.fill(1,{arg n; Buffer.read(s,Document.current.dir ++ "/dependencies/imageControlledSounds/" ++ n ++ ".wav")});

		s.sync;

		SynthDef.new(\glock, {
			arg buff, rate, amp, outBus = 0, pan = 2.0.rand - 1;
			var sig;
			rate = rate * BufRateScale.kr(buff);
			sig = PlayBuf.ar(1, buff,rate).madd(amp);
			sig = FreeVerb.ar(sig,0.3 + (0.7 * (1-amp)), 0.5 + (0.5 * (1-amp)));
			sig = sig.madd(~amp);

			// Free the synth when the signal drops below threshold for specified time
			DetectSilence.ar(sig, 0.0007, 0.1, Done.freeSelf);//amp: 0.0007, time: 0.1, doneAction: Done.freeSelf);
			EnvGen.ar(Env.perc(releaseTime: 4), doneAction: Done.freeSelf);//incase detectsilence fails to free
			Out.ar(outBus, Pan2.ar(sig, pan));
		}).add;



		SynthDef.new(\autoPan, {
			arg inBus, outBus, pan, rand;
			var sig;
			sig = In.ar(inBus);
			pan = SinOsc.ar(1 / (4 + rand)).madd(0.7);
			Out.ar(outBus,Pan2.ar(sig,pan));
		}).add;

		SynthDef.new(\dryglock, {
			arg buff, rate, amp, filt = 0, q = 0.001, freq = 440, outBus = 0, pan = 2.0.rand - 1;
			var sig, reverbTail,totalDuration;
			rate = rate * BufRateScale.kr(buff);
			sig = PlayBuf.ar(1, buff,rate);//, doneAction: Done.freeSelf);
			3.do({
				sig = Select.ar(filt,[sig,BPF.ar(sig,freq,q).madd(10)]);
			});

			sig = sig.madd(amp);
			sig = sig.madd(~amp);
			/*3.do({
			sig = Select.ar(filt,[sig,Resonz.ar(sig,freq,1/q)]);
			//sig = Resonz.ar(sig,freq,1/q);
			});*/
			reverbTail = 2; // 3 seconds max tail for room=1
			totalDuration = BufDur.kr(buff)/rate + reverbTail;

			//sig = FreeVerb.ar(sig,0.3 + (0.7 * (1-amp)), 0.5 + (0.5 * (1-amp)));
			// Free the synth when the signal drops below threshold for specified time
			DetectSilence.ar(sig, amp: 0.0007, time: 0.1, doneAction: Done.freeSelf);
			EnvGen.ar(Env.perc(releaseTime: 4), doneAction: Done.freeSelf);//incase detectsilence fails to free

			// Free after buffer duration + estimated reverb tail
			//Line.kr(0, 0, totalDuration, doneAction: Done.freeSelf);
			Out.ar(outBus, Pan2.ar(sig,pan));
		}).add;

		SynthDef.new(\reverbForGlock, {
			arg inBus = 6, outBus = 7, amp = 1;
			var sig;
			sig = In.ar(inBus,1);
			sig = FreeVerb.ar(sig,0.3 + (0.7 * (1-amp)), 0.5 + (0.5 * (1-amp)));
			Out.ar(outBus, sig);
		}).add;

		~gNote = {
			arg freq = 440, buffFreqs = ~buffFreqs;
			var bufFreq, rate, buff, a = buffFreqs.size.rand;
			bufFreq = buffFreqs[a].minItem({arg bf; (bf[1] / freq).log2.abs});
			rate = freq / bufFreq[1];
			buff = bufFreq[0];
			(
				rate: rate,
				buff: buff
			)
		};

		~saxBuf = Buffer.read(s,Document.current.dir ++ "/dependencies/samples/sax_glock_loop.wav");//sax_loop.wav");

		s.sync;


		SynthDef.new(\chordNote, {
			arg amp = 0.4, note, growDecay = 0, outBus = 0, pan = 0;
			var sig, env, envGen;
			sig = PlayBuf.ar(1,~saxBuf,BufRateScale.kr(~saxBuf) * note.lag(2).midicps / 438.0, loop: 1);
			//sig = sig.madd(amp.varlag(1,Select.kr(growDecay,[3,-5])));
			env = Env.new([0.000001, 0.9, 0.1, 1, 0.000001],
				[0.05, 0.05, 0.4, 0.5],
				[\exp, \exp, \exp, \cubed]);
			envGen = EnvGen.ar(env,timeScale:6,doneAction:Done.freeSelf);
			sig = sig.madd(envGen);
			sig = sig.madd(amp);
			sig = sig.madd(~amp);

			Out.ar(outBus, Pan2.ar(sig, pan.lag(2)));
		}).add;

		SynthDef.new(\harmonizer, {
			arg inBus = 4, outBus = 6, scaleIndex = 0, harmArrIndex = 0, amp = 1;
			var sig, midi, pc, harm, freq, hasFreq,
			harmarrs = [
				[[-2,-6,-9],[-4,-6,-9],[-3,-5,-9],[-3,-7,-9],[-3,-6,-8],[-3,-6,-10],[-2,-5,-8],[-3,-7,-10]],
				[[-3,-6,-9]],//all dim
				[[-3,-8],[-5,-8],[-4,-7],[-4,-9],[-3,-7],[-5,-9]]//aug
			],
			/*harmarrs = [
			[[12, 10, 6, 3], [12, 8, 6, 3], [12, 9, 7, 3], [12, 9, 5, 3], [12, 9, 6, 4], [12, 9, 6, 2], [12, 10, 7, 4], [12, 9, 5, 2]],
			[[12, 9, 6, 3]], // all dim
			[[12, 9, 4], [12, 7, 4], [12, 8, 5], [12, 8, 3], [12, 9, 5], [12, 7, 3]] // aug
			],*/
			harmArr,
			scaleMember, scales = [[0,1,0,2,3,0,4,5,0,6,7,0], [0,0,1,0,2,3,0,4,5,0,6,7],[7,0,0,1,0,2,3,0,4,5,0,6],
				Array.fill(12,{0}),//alldim
				[0,1,1,2,2,3,3,4,4,5,6,6,0],[0,0,1,1,2,2,3,3,4,4,5,6,6],[6,0,0,1,1,2,2,3,3,4,4,5,6],[6,6,0,0,1,1,2,2,3,3,4,4,5]//aug
			],
			oct, harmIndex, intervals;

			sig = In.ar(inBus,1);
			sig = Mix.ar(sig);
			# freq, hasFreq = Pitch.kr(sig);
			midi = freq.cpsmidi.round;

			// mod 12
			oct = (midi / 12).floor;
			pc = midi - (oct * 12);

			// Map pitch class to octatonic scale degree
			scaleMember = Select.kr(scaleIndex, scales);
			harmIndex = Select.kr(pc, scaleMember);


			harmArr = Select.kr(harmArrIndex, harmarrs);

			intervals = Select.kr(harmIndex, harmArr);
			harm = Mix.ar(intervals.collect({|interval|
				PitchShift.ar(sig, pitchRatio: interval.midiratio);
			}));
			sig = DelayN.ar(sig, 0.1, 0.05);

			// Select the appropriate harmonization based on the scale degree
			sig = Mix.ar([sig * 1, harm * 1]);
			Out.ar(outBus, sig.madd(2 * amp));
		}).add;

		SynthDef.new(\reverb, {
			arg inBus = 6, outBus = 7, mix = 1, room = 0.9;
			var sig;
			sig = In.ar(inBus,1);
			sig = FreeVerb.ar(sig,mix.lag(1),room.lag(1));
			Out.ar(outBus, sig);
		}).add;

		SynthDef.new(\pan, {
			arg inBus, outBus, pan;
			var sig;
			sig = In.ar(inBus);
			Out.ar(outBus,Pan2.ar(sig,pan));
		}).add;

		SynthDef.new(\holdReverb, {
			arg inBus = 4, outBus, feedback = 0.5, decayTime = 1, gate = 1, amp = 1;
			var sig, local, env = 1, envs;
			sig =  In.ar(inBus,1).madd(amp.lag(1));

			local = (LocalIn.ar(1) + sig);
			20.do({local = AllpassN.ar(local, 0.06,
				Rand(0.001, 0.06), decayTime)});

			LocalOut.ar(local * feedback);

			sig = Mix.ar([sig,local]);

			Out.ar(outBus,  sig);
		}).add;

		SynthDef.new(\split, {
			arg inBus = 7, outBus = 0, amp = 1;
			var sig;
			sig = In.ar(inBus,1).madd(amp);
			Out.ar(outBus, sig.dup);
		}).add;

		SynthDef.new(\mixToMono, {
			arg inBus = 7, outBus = 0;
			var sig;
			sig = In.ar(inBus,2);
			Out.ar(outBus, Mix.ar(sig));
		}).add;

		SynthDef.new(\thruStereo, {
			arg inBus = 7, outBus = 0;
			var sig;
			sig = In.ar(inBus,2);
			Out.ar(outBus, sig);
		}).add;

		SynthDef.new(\play, {
			arg outBus = 4, buff = 0, amp = 1;
			Out.ar(outBus,Mix.ar(PlayBuf.ar(2,buff,BufRateScale.kr(buff))).madd(amp).madd(~amp));
		}).add;

		SynthDef.new(\playMono, {
			arg outBus = 4, buff = 0;
			Out.ar(outBus,PlayBuf.ar(1,buff,BufRateScale.kr(buff)).madd(~amp));
		}).add;

		SynthDef.new(\playStereo, {
			arg outBus = 0, buff = 0, amp = 1;
			Out.ar(outBus,PlayBuf.ar(2,buff,BufRateScale.kr(buff)).madd(amp).madd(~amp));
		}).add;

		SynthDef.new(\lpFilter, {
			arg inBus = 4, outBus = 0;
			var sig;
			sig = In.ar(inBus,1);
			sig = LPF.ar(sig);
			Out.ar(outBus, sig);
		}).add;

		SynthDef.new(\delay, {
			arg inBus = 0, outBus = 0, delayTime = 0.5, decayTime = 3;
			var sig, dry = In.ar(inBus, 1);
			sig = dry;
			sig = CombC.ar(sig, delayTime,delayTime,decayTime);
			sig = Mix.ar([sig,dry]);
			Out.ar(outBus,sig);
		}).add;

		SynthDef.new(\thru, {
			arg inBus = 0, outBus = 0, amp = 1;
			Out.ar(outBus, In.ar(inBus).madd(amp));
		}).add;

		s.sync;

		~chords = {
			arg chords, amp = 0.4;
			var synths = [], bus1 = Bus.audio(s,2),bus2 = Bus.audio(s,2), rev1,rev2, thru;
			thru = Synth.new(\thruStereo, [\inBus, bus1.index, \outBus, 0]);
			rev1 = Synth.new(\holdReverb, [\inBus, bus2.index, \outBus, bus1.index]);
			rev2 = Synth.new(\holdReverb, [\inBus, bus2.index + 1, \outBus, bus1.index + 1]);

			"hi".postln;
			chords.postln;

			chords[0].do({
				arg note;
				var synth, pan;
				pan = [-1,1].choose;
				synth = Synth.new(\chordNote, [\note, note, \outBus, bus2.index, \pan, pan, \amp, amp]);
				"adding synth".postln;
				{
					synth.set(\pan,-1 * pan);
				}.defer(1);

				synths = synths.add(synth);
				//{synth.set(\amp,0.4)}.defer(0.01);
			});
			synths.postln;

			chords[1].do({
				arg note, index;
				{
					synths[index].set(\note,note);
				}.defer(1);
				/*{
				("setting synth" ++ index ++ " " + synths[index]).postln;
				synths[index].set(\amp, 0, \growDecay, 1);
				}.defer(3);*/
			});

			{
				thru.free;
				rev1.free;
				rev2.free;
				bus1.free;
				bus2.free;
			}.defer(14);
		};

		{
			var freqs = [132,335,362,362,379];
			~buffFreqs1 = [
				Document.current.dir ++ "/dependencies/samples/key_click1.wav",
				Document.current.dir ++ "/dependencies/samples/key_click2.wav",
				Document.current.dir ++ "/dependencies/samples/key_click3.wav",
				Document.current.dir ++"/dependencies/samples/key_click4.wav",
				Document.current.dir ++"/dependencies/samples/key_click5.wav"
			].collect({arg path, i; [Buffer.read(s,path),freqs[i]]});
			~buffFreqs1 = [~buffFreqs1];
		}.value();

		{
			var freqs = [440.0,466.1637615180899,493.8833012561241,523.2511306011972,554.3652619537442,587.3295358348151,622.2539674441618,659.2551138257398,698.4564628660078,739.9888454232689,783.9908719634986,830.6093951598903];
		}.value();
		s.sync;

		~burst = {
			arg buffFreqs = ~buffFreqs, hold = 0, oct = 0, fadeIn = false, ampFactor = 1, decayFact = 0.985, trans = 0,  scale = Scale.diminished.degrees;
			var dur = 0.01,//0.7,
			amp = 0.01, decaying = false, instOutBus = 0, burst;
			switch(hold)
			{1}{
				var holdInst1, holdInst2, filt1, filt2, revBus;
				instOutBus = Bus.audio(s,2);
				revBus = Bus.audio(s,2);

				filt1 = Synth.new(\lpFilter, [\inBus, revBus, \outBus, 0]);
				filt2 = Synth.new(\lpFilter, [\inBus, revBus.index + 1, \outBus, 1]);
				holdInst1 = Synth.new(\holdReverb, [\inBus,instOutBus,\outBus, revBus]);
				holdInst2 = Synth.new(\holdReverb, [\inBus,instOutBus.index + 1,\outBus, revBus.index + 1]);

				{
					holdInst1.free;
					holdInst2.free;
					filt1.free;
					filt2.free;
					instOutBus.free;
					revBus.free;
				}.defer(30);
			}
			{2}{
				var holdInst1, holdInst2, del1, del2, revBus, bus1, bus2, dels = [], busses;
				instOutBus = Bus.audio(s,2);
				revBus = Bus.audio(s,2);
				bus1 = Bus.audio(s,2);
				bus2 = Bus.audio(s,2);
				busses = List[instOutBus,revBus,bus1,bus2];

				del1 = Synth.new(\delay, [\inBus, bus2, \outBus, 0]);
				del2 = Synth.new(\delay, [\inBus, bus2.index + 1, \outBus, 1]);
				dels = dels.add(del1,del2);
				3.do({
					del1 = Synth.new(\delay, [\inBus, bus1, \outBus, bus2]);
					del2 = Synth.new(\delay, [\inBus, bus1.index + 1, \outBus, bus2.index + 1]);
					dels = dels.add(del1,del2);
					bus2 = bus1;
					bus1 = Bus.audio(s,2);
					busses.insert(0,bus1);
				});

				holdInst1 = Synth.new(\reverb, [\inBus,instOutBus,\outBus, bus2]);//bu2 is old bus1
				holdInst2 = Synth.new(\reverb, [\inBus,instOutBus.index + 1,\outBus, bus2.index + 1]);

				{
					holdInst1.free;
					holdInst2.free;
					dels.do({arg del; del.free});
					busses.do({arg bus; bus.free});


				}.defer(30);
			};
			burst = Pbind.new(
				\instrument, \glock,
				\dummy, Pfunc( {
					arg ev;
					var freq;
					freq = (scale.choose + 36 + (12 * oct) + trans).midicps;
					ev.putAll(~gNote.(freq,buffFreqs));
					ev;
				}),
				\dur, Routine({
					while{decaying.not}{
						(dur * 1.0.rand).yield;
						//dur = dur * 0.3;
					};
					loop{
						if(dur > 0.4){burst.stop};
						(dur * 1.0.rand).yield;
						dur = dur * (0.045 + decayFact);
					}
				}),
				\amp, Routine({
					while{amp < 1}{
						((amp * ampFactor).max(0.001)).yield;
						if(fadeIn){amp = amp / decayFact}{amp = amp * 1.1};
						amp = 1.min(amp);
					};
					decaying = true;
					amp = 1;
					loop{
						((amp * ampFactor).max(0.001)).yield;
						amp = amp * decayFact;//* 0.98;
					}
				}),
				\outBus, instOutBus
			).play;
		};
		s.sync;

		{
			//set up live processing effects
			//these busses do not need to be freed. They are active the whole time
			var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1),bus3 = Bus.audio(s,1),bus4 = Bus.audio(s,1),bus5 = Bus.audio(s,1),bus6 = Bus.audio(s,1),bus7 = Bus.audio(s,1), harmSplit, harmRev,pan,delay1,delay2,thru,hold, harm, harmThru;

			~micOutBus = Bus.audio(s,1); // in PROD  = SoundIn.ar(0);


			harmSplit = Synth.new(\split, [\inBus, bus4, \outBus, 0]);
			~harmRev = Synth.new(\reverb, [\inBus, bus3, \outBus, bus4, \mix, 1]);

			harm = Synth.new(\harmonizer, [\inBus, bus2,//bus2,
				\outBus, bus3, \amp, 1]);

			harmThru = Synth.new(\thru, [\inBus, bus2, \outBus, bus4]);

			~harmonizerEffect = Synth.new(\thru, [\inBus, ~micOutBus, \outBus, bus2, \amp, 1]);

			//route mic to hold
			pan = Synth.new(\autoPan, [\inBus, bus6, \outBus, 0, \rand, 2.0.rand]);

			delay1 = Synth.new(\delay, [\delayTime, 1, \inBus, bus5,\outBus, bus6]);
			delay2 = Synth.new(\delay, [\delayTime, 4 / 3.0, \inBus, bus4,\outBus, bus5]);

			thru = Synth.new(\thru, [\inBus, bus4, \outBus, bus6]);//undelayed copy also goes from hold to pan

			~revDelEffect = Synth.new(\holdReverb, [\inBus, ~micOutBus, \outBus, bus4, \amp, 0]);//must creat prior to play

		}.value;

		s.sync;

		~test = {
			fork{
				var bus1 = Bus.audio(s,2), bus2 = Bus.audio(s,1),bus3 = Bus.audio(s,1), bus4 = Bus.audio(s,1);
				~b1 = Buffer.read(s,Document.current.dir++"/dependencies/samples/melody.wav");
				~b2 = Buffer.read(s,Document.current.dir++"/dependencies/samples/saxTexture.wav");
				s.sync;

				//e = Synth.new(\mixToMono, [\inBus, bus1, \outBus, bus2]);
				d = Synth.new(\playMono,[\buff,~b1, \outBus, ~micOutBus,//bus2,
					\amp, 0.5]);

				{
					var filePath = Document.current.dir ++ "/dependencies/cues.scd";
					filePath.load;
				}.value;

				s.sync;

				~cuesData.do({arg cueDatum;
					//"string"[0] = char "s"
					{~activateCue.(cueDatum[1][0])}.defer(cueDatum[0]);
				});

				//{~harmonizerEffect.set(\scaleIndex,1); "trans changed".postln;}.defer(15);
				//{~harmonizerEffect.set(\scaleIndex,3,\harmArrIndex, 1)}.defer(31);
				//{~harmonizerEffect.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;}.defer(37.5);//40);
				//{~harmonizerEffect.set(\scaleIndex,1,\harmArrIndex, 0); "trans changed".postln;}.defer(53);
				//{~harmonizerEffect.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;}.defer(58.5);

				Synth.new(\playStereo,[\buff,~b1, \outBus, 0, \amp, 0.5]);
				//~play.(~b2);
				Synth.new(\playStereo, [\buff, ~b2, \outBus, 0, \amp, 1]);
			};
		};
		s.sync;

		{
			var filePath = Document.current.dir ++ "/dependencies/mouseStreams_v2.scd";
			filePath.load;
		}.value;

		{
			var filePath = Document.current.dir ++ "/dependencies/loadSaxText.scd";
			filePath.load;
		}.value;

		{
			var filePath = Document.current.dir ++ "/dependencies/drones.scd";
			filePath.load;
		}.value;

	}
});

{
	var filePath = Document.current.dir ++ "/dependencies/gui_final.scd";
	filePath.load;
}.value;

~cues = List.new();//define cues
~cues.insert(0,{//cue 0
	//all defaults + lowered amp
	~burst.(~buffFreqs,0,0,false,0.8);
	~resumeDrones.value;
	~drones.trans = 0;
	("1 q @ " ++ ~getTime.value).postln;
});
~cues.insert(1,{//cue 1
	~burst.(~buffFreqs1,0,3);
	("2 w @ " ++ ~getTime.value).postln;

});

~cues.insert(2,{//cue 2
	~burst.(~buffFreqs,0,6/12.0);
	{~burst.(~buffFreqs,0,3/12.0, false, 0.5);}.defer(1);
	{~burst.(~buffFreqs1,0,3,true,1.5);}.defer(1.5);
	("3 e @ " ++ ~getTime.value).postln;
});

~cues.insert(3,{//cue 3
	~chords.([[60,63,66,70],[61,64,67,69]] + 12, 0.7);
});

~cues.insert(4,{//cue 4
	Synth.new(\playStereo, [\buff, ~samples[1]]);
	~harmonizerEffect.set(\scaleIndex,1); "trans changed".postln;//
	~drones.trans = 1;
	("granular swell e @ " ++ ~getTime.value).postln;
});

~cues.insert(5,{//cue 5
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[2], \outBus, bus1]);

	{rev1.free; rev2.free; bus1.free; bus2.free;}.defer(45);
	("harmonic fractal e @ " ++ ~getTime.value).postln;

});

~cues.insert(6,{//cue 6
	~chords.([[60,63,66,70],[61,64,67,69]] + 12 + 1, 0.3);
	~chords.([[60,63,66,70],[61,64,67,69]] + 0 + 1, 0.3);
	~chords.([[60,63,66,70],[61,64,67,69]] - 12 + 1, 0.3);
	~harmonizerEffect.set(\scaleIndex,3,\harmArrIndex, 1);
	~drones.trans = 2;
});

~cues.insert(7,{//7
	~chords.([([60,63,66,70] + 1),[61,64,67,69]] + 12, 0.6);
	~harmonizerEffect.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;
	~drones.trans = 0;
});

~cues.insert(8,{//8
	~burst.(~buffFreqs1,0,3,false,0.5, 0.985,1);
	~burst.(~buffFreqs1,0,4,false,0.5, 0.985,1);
	("2 w @ " ++ ~getTime.value).postln;
	~harmonizerEffect.set(\scaleIndex,1,\harmArrIndex, 0);
});

~cues.insert(9,{//9
	~harmonizerEffect.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;
	~pauseDrones.value;
});

~cues.insert(10,{//cue 10
	//all defaults + lowered amp
	~burst.(~buffFreqs,0,0,false,0.8);
	("1 q @ " ++ ~getTime.value).postln;
	~scale = [0,1,4,5,8,9];
	~trans = 0;
	~mouseX = 1;
	~mouseY = 1;
	SystemClock.clear(~schedTarg);
	~targX = 0.1;
	~targY = 0.5;
	~mouseStreams.do({arg p; p.resume});

});

~cues.insert(11,{//11
	~scale = [0,1,4,5,8,9];
	~trans = 4;
	~mouseStreams.do({arg p; p.resume});
	SystemClock.clear(~schedTarg);
	~targX = 1;
	~targY = 0;
	~schedTarg = SystemClock.sched(3.9, {
		~targX = 0.1;
		~targY = 0.5;
		nil;
	});
});

~cues.insert(12,{//12
	~scale = [0,1,4,5,8,9];
	~trans = 0;
	~harmonizerEffect.set(\scaleIndex,4,\harmArrIndex, 2);
	~mouseStreams.do({arg p; p.resume});

	SystemClock.clear(~schedTarg);
	~targX = 1;
	~targY = 1;
	~schedTarg = SystemClock.sched(3.9, {
		~targX = 0.1;
		~targY = 0.5;
		nil;
	});
});
~cues.insert(13,{//13
	~scale = [0,1,4,5,8,9];
	~trans = 1;
	~mouseStreams.do({arg p; p.resume});
	SystemClock.clear(~schedTarg);
	~targX = 1;
	~targY = 0;
	~schedTarg = SystemClock.sched(2, {
		SystemClock.clear(~schedTarg);
		~targX = 0.1;
		~targY = 0.5;
		~schedTarg = SystemClock.sched(2, {
			~targX = 1;
			~targY = 1;
			nil;
		});
	});
});

~cues.insert(14,{//14
	~scale = [0,1,4,5,8,9];
	~trans = 2;
	~mouseStreams.do({arg p; p.resume});
	~harmonizerEffect.set(\scaleIndex,6,\harmArrIndex, 2);

	SystemClock.clear(~schedTarg);
	~targX = 0;
	~targY = 0;


	~drones.trans = 0;
	~resumeDrones.value;
});

// ******************** END EXPO ***************************
~cues.insert(15,{//15
	~mouseStreams.do({arg p; p.pause});
	"CUE 15".postln;
	~harmonizerEffect.set(\amp, 0);
});

//keyburst1
~cues.insert(16,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[3], \outBus, bus1]);

	{rev1.free; rev2.free;bus1.free;bus2.free;}.defer(45);
	("keyburst e @ " ++ ~getTime.value).postln;
	~drones.trans = 2;//alternating between "home scales in oct dev 1"
});

~cues.insert(17,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[4], \outBus, bus1]);
	{bus1.free;bus2.free;rev1.free;rev2.free;}.defer(20);
	("keyburstl e @ " ++ ~getTime.value).postln;
	~drones.trans = 0;//alternating between "home scales in oct dev 1"
});

~cues.insert(18,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[5], \outBus, 1]);
	{bus1.free;bus2.free;rev1.free;rev2.free;}.defer(20);
	("keyburst e @ " ++ ~getTime.value).postln;
	~drones.trans = 2;//alternating between "home scales in oct dev 1"
});
~cues.insert(19,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[6], \outBus, bus1]);
	{bus1.free;bus2.free;rev1.free;rev2.free;}.defer(20);
	("keyburst e @ " ++ ~getTime.value).postln;
	~drones.trans = 0;//alternating between "home scales in oct dev 1"
});

~cues.insert(20,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[7], \outBus, bus1]);
	{bus1.free;bus2.free;rev1.free;rev2.free;}.defer(20);
	("murmer e @ " ++ ~getTime.value).postln;
	~drones.trans = 2;//alternating between "home scales in oct dev 1"

});

// ******************** END OCT DEV 1 ***************************

~cues.insert(21,{//change pitch field
	~drones.trans = 3;
	~drones.scale = Scale.augmented.degrees;
});

~cues.insert(22,{
	~chords.([[60,63,67],[59,64,68]] + 12, 0.7);
	~drones.trans = 1;
});

~cues.insert(23,{
	~chords.([[60,63,67],[59,64,68]] + 12 - 2, 0.4);
	~chords.([[60,63,67],[59,64,68]] + 0 - 2, 0.4);
	~chords.([[60,63,67],[59,64,68]] - 12 - 2, 0.4);
	~drones.trans = 2;
});

// ******************** END HEX DEV 3 ***************************

//see loadSaxText.scd
~cues.insert(24,{
	var toPlay = [0];
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
			("SCHEDULING PROCESS W CONT INDEX: " + i).postln;
		};
		~playText[i] = toPlay.includes(i);
	});

	~pauseDrones.value;

	~chords.([[59,64,68],[60,63,67]] + 12 - 1, 0.5);
	~chords.([[59,64,68],[60,63,67]] + 24 - 1, 0.5);
	~harmonizerEffect.set(\amp, 0);
	~revDelEffect.set(\amp, 1);

});


~cues.insert(25,{
	var toPlay = [1];
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
			("SCHEDULING PROCESS W CONT INDEX: " + i).postln;
		};
		~playText[i] = toPlay.includes(i);
	});
});

//cue
~cues.insert(26,{
	var toPlay = [1,2];
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
			("SCHEDULING PROCESS W CONT INDEX: " + i).postln;
		};
		~playText[i] = toPlay.includes(i);
	});
});

//cue
~cues.insert(27,{
	var toPlay = [1,2,3];
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
			("SCHEDULING PROCESS W CONT INDEX: " + i).postln;
		};
		~playText[i] = toPlay.includes(i);
	});
});

//cue
~cues.insert(28,{
	~chords.([[59,64,68],[58,62,65]] + 12, 0.5);
	~chords.([[59,64,68],[58,62,65]] + 24, 0.5);
});

//cue
~cues.insert(29,{
	var bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[8], \outBus, bus1]);

	{rev1.free; rev2.free; bus1.free; bus2.free;}.defer(45);
	("harmonic fractal e @ " ++ ~getTime.value).postln;
});

//cue
~cues.insert(30,{
	var toPlay = [1,2,3,4],bus1 = Bus.audio(s,1),bus2 = Bus.audio(s,1), rev1,rev2;
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
		};
		~playText[i] = toPlay.includes(i);
	});
	rev1 = Synth.new(\holdReverb, [\inBus, bus1, \outBus, 0]);
	rev2 = Synth.new(\holdReverb, [\inBus, bus1.index + 1, \outBus, 1]);
	Synth.new(\playStereo, [\buff, ~samples[9], \outBus, bus1]);

	{rev1.free; rev2.free; bus1.free; bus2.free;}.defer(45);
});

~cues.insert(31,{
	var toPlay = [];
	~playText.size.do({arg i;
		if(toPlay.includes(i) && ~playText[i].not){
			~sched.value(~bufIndexes[i],i);
		};
		~playText[i] = toPlay.includes(i);
	});
	//~revDelEffect.set(\amp, 0);
});

~cues.insert(32,{
	~chords.([[59,64,67],[58,61,65]] + 0, 0.5);
	~chords.([[59,64,67],[58,61,65]] + 12, 0.5);
	~chords.([[59,64,67],[58,61,65]] + 24, 0.5);
});

~cues.insert(33,{
	~chords.([[59,64,67],[58,61,65]] + 0 + 1, 0.5);
	~chords.([[59,64,67],[58,61,65]] + 12 + 1, 0.5);
	~chords.([[59,64,67],[58,61,65]] + 24 + 1, 0.5);
});

~cues.insert(34,{
	~chords.([[59,64,67],[58,62,65]] + 12 + 2, 0.5);
	~chords.([[59,64,67],[58,62,65]] + 24 + 2, 0.5);
	~chords.([[59,64,67],[58,62,65]] + 0 + 2, 0.5);
});

~cues.insert(35,{
	~chords.([[59,64,68],[58,61,65]] + 12 + 3, 0.5);
	~chords.([[59,64,68],[58,61,65]] + 24 + 3, 0.5);
	~chords.([[59,64,68],[58,61,65]] + 0 + 3, 0.5);
});

~cues.insert(36,{
	~chords.([[59,64,68],[58,62,65]] + 12 + 3, 0.5);
	~chords.([[59,64,68],[58,62,65]] + 24 + 3, 0.5);
	~chords.([[59,64,68],[58,62,65]] + 0 + 3, 0.5);
	~chords.([[59,64,68],[58,62,65]] - 12 + 3, 0.5);
});

)




