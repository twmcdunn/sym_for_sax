(
Server.default.options.memSize = 128000;
s.reboot;
s.waitForBoot({
	fork {
		~play = {
			arg buff;
			{PlayBuf.ar(2,buff, BufRateScale.kr(buff))}.play;
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

		~loadGlockBuffFreqs.("/Users/maestro/Documents/Coding/EP_Fixed_Media/resources/glock_samples");

		s.sync;

		SynthDef.new(\glock, {
			arg buff, rate, amp, outBus = 0;
			var sig;
			rate = rate * BufRateScale.kr(buff);
			sig = PlayBuf.ar(1, buff,rate,doneAction: Done.freeSelf).madd(amp);
			sig = FreeVerb.ar(sig,0.3 + (0.7 * (1-amp)), 0.5 + (0.5 * (1-amp)));
			Out.ar(outBus, sig.dup);
		}).add;

		~gNote = {
			arg freq = 440;
			var bufFreq, rate, buff, a = 4.rand;
			bufFreq = ~buffFreqs[a].minItem({arg bf; (bf[1] / freq).log2.abs});
			rate = freq / bufFreq[1];
			buff = bufFreq[0];
			(
				rate: rate,
				buff: buff
			)
		};

		~saxBuf = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/sax_loop.wav");

		s.sync;


		SynthDef.new(\chordNote, {
			arg amp, note, growDecay = 0, outBus = 0, pan = 0;
			var sig;
			sig = PlayBuf.ar(1,~saxBuf,BufRateScale.kr(~saxBuf) * note.lag(2).midicps / 438.0, loop: 1);
			sig = sig.madd(amp.varlag(1,Select.kr(growDecay,[3,-5])));
			Out.ar(outBus, Pan2.ar(sig, pan.lag(2)));
		}).add;

		SynthDef.new(\harmonizer, {
			arg inBus = 4, outBus = 6, scaleIndex = 0, harmArrIndex = 0;
			var sig, midi, pc, harm, freq, hasFreq,
			harmarrs = [
				[[-2,-6,-9],[-4,-6,-9],[-3,-5,-9],[-3,-7,-9],[-3,-6,-8],[-3,-6,-10],[-2,-5,-8],[-3,-7,-10]],
				[[-3,-6,-9]],
			], harmArr,
			scaleMember, scales = [[0,1,0,2,3,0,4,5,0,6,7,0], [0,0,1,0,2,3,0,4,5,0,6,7],[7,0,0,1,0,2,3,0,4,5,0,6],Array.fill(12,{0})],
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
			sig = Mix.ar([sig * 0.5, harm]);
			Out.ar(outBus, sig);
		}).add;

		SynthDef.new(\reverb, {
			arg inBus = 6, outBus = 7;
			var sig;
			sig = In.ar(inBus,1);
			sig = FreeVerb.ar(sig,0.8,9);
			Out.ar(outBus, sig);
		}).add;

		SynthDef.new(\split, {
			arg inBus = 7, outBus = 0;
			var sig;
			sig = In.ar(inBus,1);
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
			arg bus = 4, buff = 0;
			Out.ar(bus,Mix.ar(PlayBuf.ar(2,buff,BufRateScale.kr(buff))));
		}).add;
	}
});
)

(
~chords = {
	arg chords;
	var synths = [], bus1 = Bus.audio(s,2),bus2 = Bus.audio(s,2), rev1,rev2, thru;
	thru = Synth.new(\thruStereo, [\inBus, bus1.index, \outBus, 0]);
	rev1 = Synth.new(\reverb, [\inBus, bus2.index, \outBus, bus1.index]);
	rev2 = Synth.new(\reverb, [\inBus, bus2.index + 1, \outBus, bus1.index + 1]);

	"hi".postln;
	chords.postln;

	chords[0].do({
		arg note;
		var synth, pan;
		pan = [-1,1].choose;
		synth = Synth.new(\chordNote, [\note, note, \amp, 0, \outBus, bus2.index, \pan, pan]);
		"adding synth".postln;
		{
			synth.set(\pan,-1 * pan);
		}.defer(1);

		synths = synths.add(synth);
		{synth.set(\amp,0.4)}.defer(0.01);
	});
	synths.postln;

	chords[1].do({
		arg note, index;
		{
			synths[index].set(\note,note);
		}.defer(1);
		{
			("setting synth" ++ index ++ " " + synths[index]).postln;
			synths[index].set(\amp, 0, \growDecay, 1);
		}.defer(3);

		{
			("setting synth" ++ index ++ " " + synths[index]).postln;
			synths[index].free;
			thru.free;
			rev1.free;
			rev2.free;
		}.defer(14);
	});
};
)

~chords.([[60,63,66,70],[61,64,67,69]] + 12);
~chords.([[60,63,66,70],[61,64,67,69]]);
~chords.([[60,63,66,70],[61,64,67,69]] - 12);


~drone = Synth.new(\drone, [\freq, 440, \amp, 0]);

~drone.set(\amp, 1,\freq, 440, \growDecay, 0);
~drone.set(\amp, 0,\freq, 550, \growDecay, 1);
{PlayBuf.ar(1,~saxBuf).dup}.play;

(
fork{
	~b1 = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/melodyTemplate.wav");
	~b2 = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/saxTexture.wav");
	s.sync;
	c = Synth.new(\split);
	b = Synth.new(\reverb);
	a = Synth.new(\harmonizer);
	d = Synth.new(\play,[\buff,~b1]);

	{a.set(\scaleIndex,1); "trans changed".postln;}.defer(15);
	{a.set(\scaleIndex,3,\harmArrIndex, 1)}.defer(31);
	{a.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;}.defer(40);
	{a.set(\scaleIndex,1,\harmArrIndex, 0); "trans changed".postln;}.defer(54);
	{a.set(\scaleIndex,0,\harmArrIndex, 0); "trans changed".postln;}.defer(58.5);


	/*{PlayBuf.ar(2,~b1 * Buff)}.play;
	{PlayBuf.ar(2,~b2)}.play;*/
	~play.(~b1);
	~play.(~b2);
};
)

(
var dur = 0.01,//0.7,
amp = 0.01, decaying = false, burst;
burst = Pbind.new(
	\instrument, \glock,
	\dummy, Pfunc( {
		arg ev;
		var freq;
		freq = (Scale.diminished.degrees.choose + 36).midicps;
		ev.putAll(~gNote.(freq));
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
			dur = dur * 1.03;
		}
	}),
	\amp, Routine({
		while{amp < 1}{
			(amp).yield;
			amp = amp * 1.1;
			amp = 1.min(amp);
		};
		decaying = true;
		amp = 1;
		loop{
			amp.yield;
			amp = amp * 0.985;//* 0.98;
		}
	}),
).play;
)

