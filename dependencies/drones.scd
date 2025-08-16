(
~drones = {
	var scale = Scale.diminished.degrees, trans = 0, sched, resume, pause;

	fork{
		var buffs = [
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/susBell.wav"),
			Buffer.read(s,Document.current.dir ++ "/dependencies/samples/susBell1.wav")
		], playBell;
		s.sync;
		SynthDef.new(\susBell, {
			arg outBus = 4, freq = 440, amp = 0.1, buff;
			var sig = PlayBuf.ar(1,buff,BufRateScale.kr(buff) * freq / 1174.0);
			sig = Mix.ar(sig);
			sig = sig.madd(amp);
			sig = sig.madd(~amp);
			Out.ar(outBus,sig);
		}).add;
		s.sync;
		SynthDef.new(\autoPanForDrone, {
			arg inBus, outBus, pan, rand;
			var sig;
			sig = In.ar(inBus);
			pan = SinOsc.ar(1 / (5 + rand)).madd(0.7);
			Out.ar(outBus,Pan2.ar(sig,pan));
		}).add;
		/*SynthDef.new(\reverb, {
		arg inBus = 6, outBus = 7;
		var sig;
		sig = In.ar(inBus,1);
		sig = FreeVerb.ar(sig,1,3);
		Out.ar(outBus, sig);
		}).add;*/
		s.sync;
		playBell = {
			var bus1 = Bus.audio(s,2),bus2 = Bus.audio(s,1), synths = List.new();//1174hz
			synths.insert(0,Synth.new(\reverb, [\inBus, bus1, \outBus,0]));
			synths.insert(0,Synth.new(\reverb, [\inBus, bus1.index + 1, \outBus,1]));
			synths.insert(0,Synth.new(\autoPanForDrone, [\inBus, bus2, \outBus,bus1]));
			synths.insert(0,Synth.new(\susBell, [\freq, (scale.choose + 84 + trans).midicps, \amp, 1.0.rand, \buff, buffs[0], \outBus,bus2]));
			{
				synths.do({arg synth; synth.free});
				bus1.free;
				bus2.free;
			}.defer(60);
		};
		s.sync;



		~resumeDrones= {
			("RESUMING").postln;
			SystemClock.clear(sched);
			sched = SystemClock.sched(0, {
				playBell.value;
				(3.0.rand);
			});
		};

		~pauseDrones = {
			SystemClock.clear(sched);
		};

	};

	(
		scale: scale,
		trans: trans
	)
}.value;
)

