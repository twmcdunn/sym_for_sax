

(
Server.default.options.memSize = 128000;
s.reboot;
s.waitForBoot({
	fork {
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

		SynthDef.new(\dryglock, {
			arg buff, rate, amp, filt = 0, q = 0.001, freq = 440, outBus = 0, pan = 2.0.rand - 1;
			var sig, reverbTail,totalDuration;
			rate = rate * BufRateScale.kr(buff);
			sig = PlayBuf.ar(1, buff,rate);//, doneAction: Done.freeSelf);
			3.do({
				sig = Select.ar(filt,[sig,BPF.ar(sig,freq,q).madd(10)]);
			});

			sig = sig.madd(amp);
			/*3.do({
				sig = Select.ar(filt,[sig,Resonz.ar(sig,freq,1/q)]);
				//sig = Resonz.ar(sig,freq,1/q);
			});*/
			reverbTail = 2; // 3 seconds max tail for room=1
			totalDuration = BufDur.kr(buff)/rate + reverbTail;

			//sig = FreeVerb.ar(sig,0.3 + (0.7 * (1-amp)), 0.5 + (0.5 * (1-amp)));
			// Free the synth when the signal drops below threshold for specified time
			DetectSilence.ar(sig, amp: 0.0007, time: 0.1, doneAction: Done.freeSelf);

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

		s.sync;

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

		{
			var freqs = [132,335,362,362,379];
			~buffFreqs1 = [
				"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/samples/key_click1.wav",
				"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/samples/key_click2.wav",
				"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/samples/key_click3.wav",
				"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/samples/key_click4.wav",
				"/Users/maestro/Documents/Coding/innerSoundScape3/resources/samples/samples/key_click5.wav"
			].collect({arg path, i; [Buffer.read(s,path),freqs[i]]});
			~buffFreqs1 = [~buffFreqs1];
		}.value();


		/////////////////////////////////begin mouse texture logic*******************************************

		~buffFreqsToUse = ~buffFreqs;

		~glockBus = Bus.audio(s,2);
		~glockGroup = Group.new;
		~revForGlock = [Synth.new(\reverbForGlock, [\inBus, ~glockBus, \outBus, 0]),Synth.new(\reverbForGlock, [\inBus, ~glockBus.index + 1, \outBus, 1])];
		~mouseY = 0;
		~mouseX = 0;
		~deltX = 0;
		~deltY = 0;
		~mouseV = 0;
		//starts sending mouseY values to the client
		{SendReply.kr(Impulse.kr(20), '/mouseY', MouseY.kr(),-1)}.play;
		if(~yMessages.notNil){~yMessages.free};
		~yMessages = OSCFunc.newMatching({
			arg msg;
			~deltY = (msg[3] - ~mouseY).abs;
			~mouseY = msg[3];
			~mouseV = (~deltY ** 2 + ~deltX ** 2).pow(0.5);
		}, '/mouseY');

		//starts sending mouseX values to the client
		{SendReply.kr(Impulse.kr(20), '/mouseX', MouseX.kr(), -1)}.play;
		if(~xMessages.notNil){~xMessages.free};
		~xMessages = OSCFunc.newMatching({
			arg msg;
			~deltX = (msg[3] - ~mouseX).abs;
			~mouseX = msg[3];
			~mouseV = (~deltY ** 2 + ~deltX ** 2).pow(0.5);
			~revForGlock[0].set(\amp, ((~mouseX * 0.1).exp - 1) / ((0.1).exp - 1));
			~revForGlock[1].set(\amp, ((~mouseX * 0.1).exp - 1) / ((0.1).exp - 1));

		}, '/mouseX');

		~scale = [0,1,3,4,6,7,9,10];
		~trans = 0;

		~mouseStreams = Array.newClear(7);

		s.sync;
		7.do({
			|n|
			var oct = n - 3;
			p = Pbind.new(
				\instrument, \dryglock,
				\dummy, Pfunc{ |ev|
					var hs, freq, offset, osClass;
					hs = (~scale.choose + ~trans) % 12;
					hs = (hs + 10) % 12;//so that pc equals input after transposition below
					offset = (24 * ~mouseY).round;
					osClass = offset % 12;
					hs = ((hs - osClass) % 12) + osClass + ((offset / 12).floor * 12);
					freq = 440 * (2 ** ((hs - 10) / 12)) * (2 ** oct);//-10 puts it in middle of glock samples
					ev.putAll((freq: freq, filt:0));
					ev.putAll(~gNote.(freq, ~buffFreqsToUse));

					ev;
				},
				\amp,
				FuncStream({
					var density = ((~mouseX * 0.1).exp - 1) / ((0.1).exp - 1),
					octDecay = 0.5 + (0.5 * ~mouseX);
					density = density * (octDecay ** oct.abs);
					density;
				}),
				\dur, FuncStream({
					var density = ((~mouseV.min(0.2) * 10).exp - 1) / ((0.2 * 10).exp - 1);
					Array.fill(3,{|i| (i+1) * 0.03}).choose;// + (0.1 * (1-density));
				}),
				\outBus, ~glockBus
			).play;
			~mouseStreams[n] = p;
		}
		);

	}
});
)

~gNote.(440)



~gNote.(440)
~buffFreqsToUse = ~buffFreqs1
~trans = 0

s.boot;

// execute the code below to find out a key's keycode
// the char and keycode of any key you press will be printed in the post window
(
w = Window.new("I catch keystrokes");
w.view.keyDownAction = { |view, char, modifiers, unicode, keycode|  [char, keycode].postln };
w.front;
)

// then execute this and then press the 'j' key
(
w.front; // something safe to type on
{ SinOsc.ar(800, 0, KeyState.kr(49, 0, 0.1)) }.play;
)
{ SinOsc.ar(800, 0, KeyState.kr(49, 0, 0.1)) }.play;
{SinOsc.ar(800,0,1)}.play
-3 % 12;
p.stop;
~mouseV
(-1*(1-(0))).exp

~mouseX
(
{
	var hs = 3, offset = -9, osClass = offset % 12;
	hs = ((hs - osClass) % 12) + osClass + ((offset / 12).floor * 12);
	hs;
}.value();
)


