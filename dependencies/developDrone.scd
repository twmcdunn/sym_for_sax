(
fork{
	SynthDef.new(\holdReverb, {
		arg inBus = 4, outBus, feedback = 0.9, decayTime = 1, gate = 1;
		var sig, local, env = 1, envs;
		sig =  In.ar(inBus,1);

		local = (LocalIn.ar(1) + sig);
		20.do({local = AllpassN.ar(local, 0.06,
			Rand(0.001, 0.06), decayTime)});

		LocalOut.ar(local * feedback);

		sig = Mix.ar([sig,local]);

		Out.ar(outBus,  sig.dup);
	}).add;

	SynthDef.new(\play, {
		arg outBus = 4, buff = ~buff, freq = 440, amp = 0.1;
		Out.ar(outBus,Mix.ar(PlayBuf.ar(1,buff,BufRateScale.kr(buff) * freq / 1177.0)).madd(amp));
	}).add;

	s.sync;

	~buff = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/sc_modules/samples/glock_samples/348870__cabled_mess__glockenspiel_04_d3_04.wav");

	s.sync;
	Synth.new(\holdReverb);
	Synth.new(\play, [\buff, ~buff, \freq, 1177]);

	8.do({
	});
}
)
(
{
	var scale = Scale.diminished.degrees, trans = 0;
	fork{
		var buffs = [
			Buffer.read(s,Document.current.dir ++ "/samples/susBell.wav"),
			Buffer.read(s,Document.current.dir ++ "/samples/susBell1.wav")
		], playBell, sched;
		s.sync;
		SynthDef.new(\susBell, {
			arg outBus = 4, freq = 440, amp = 0.1, buff;
			Out.ar(outBus,Mix.ar(PlayBuf.ar(1,buff,BufRateScale.kr(buff) * freq / 1174.0)).madd(amp));
		}).add;
		s.sync;
		SynthDef.new(\autoPanForDrone, {
			arg inBus, outBus, pan, rand;
			var sig;
			sig = In.ar(inBus);
			pan = SinOsc.ar(1 / (5 + rand)).madd(0.7);
			Out.ar(outBus,Pan2.ar(sig,pan));
		}).add;
		SynthDef.new(\reverb, {
			arg inBus = 6, outBus = 7;
			var sig;
			sig = In.ar(inBus,1);
			sig = FreeVerb.ar(sig,1,3);
			Out.ar(outBus, sig);
		}).add;
		s.sync;
		playBell = {
			var bus1 = Bus.audio(s,2),bus2 = Bus.audio(s,1), synths = List.new();//1174hz
			synths.insert(0,Synth.new(\reverb, [\inBus, bus1, \outBus,0]));
			synths.insert(0,Synth.new(\reverb, [\inBus, bus1.index + 1, \outBus,1]));
			synths.insert(0,Synth.new(\autoPanForDrone, [\inBus, bus2, \outBus,bus1]));
			synths.insert(0,Synth.new(\susBell, [\freq, (scale.choose + 84 + trans).midicps, \amp, 0.1.rand, \buff, buffs.choose, \outBus,bus2]));
			{
				synths.do({arg synth; synth.free});
				bus1.free;
				bus2.free;
			}.defer(60);
		};
		s.sync;

		sched = SystemClock.sched(0, {
			playBell.value;
			(3.0.rand);
		});



	};

	(
		scale: scale,
		trans: trans
	)

}.value;
)

~b = Bus.audio(s,1);
~b1 = Bus.audio(s,1);
~b.index;
~b.free;