(
fork{
	SynthDef.new(\delaySaxText, {
		arg inBus = 0, outBus = 0, delayTime = 0.5, decayTime = 3;
		var sig, dry = In.ar(inBus, 1);
		sig = dry;
		sig = CombC.ar(sig, delayTime,delayTime,decayTime);
		sig = Mix.ar([sig,dry]);
		Out.ar(outBus,sig);
	}).add;

	SynthDef.new(\playSaxText, {
		arg buf, outBus = ~in, amp = 0.5;
		var sig;
		sig = PlayBuf.ar(1,buf,loop: 1);
		sig = Mix.ar(sig).madd(amp.varlag(5,4));
		Out.ar(outBus, sig);
	}).add;

	SynthDef.new(\holdReverbSaxText, {
		arg inBus = 4, outBus, feedback = 0.5, decayTime = 1, gate = 1;
		var sig, local, env = 1, envs;
		sig =  In.ar(inBus,1);

		local = (LocalIn.ar(1) + sig);
		20.do({local = AllpassN.ar(local, 0.06,
			Rand(0.001, 0.06), decayTime)});

		LocalOut.ar(local * feedback);

		sig = Mix.ar([sig,local]);

		Out.ar(outBus,  sig);
	}).add;

	SynthDef.new(\lpSaxText, {
		arg buf, outBus, inBus;
		var sig;
		sig = In.ar(inBus,1);
		sig = LPF.ar(sig,880);
		Out.ar(outBus, sig);
	}).add;

	SynthDef.new(\autoPan, {
		arg inBus, outBus, pan, rand;
		var sig;
		sig = In.ar(inBus);
		pan = SinOsc.ar(1 / (5 + rand)).madd(0.7);
		Out.ar(outBus,Pan2.ar(sig,pan));
	}).add;

	s.sync;
	~b0 = Buffer.read(s,Document.current.dir ++ "/samples/sax1.wav");
	s.sync;


	~saxTextNodes = List.new(8);

	~sched = {
		arg busIndex, cont;
		var synth,
		bus1 = Bus.audio(s,1), bus2 = Bus.audio(s,1), bus3 = Bus.audio(s,1), bus4 = Bus.audio(s,1),
		busses = [bus1,bus2,bus3,bus4];
		//"addingNodes".postln;

		~saxTextNodes.insert(0,Synth.new(\autoPan, [\inBus, bus4, \outBus, 0]));
		~saxTextNodes.insert(0,Synth.new(\holdReverbSaxText, [\inBus, bus3, \outBus, bus4]));
		~saxTextNodes.insert(0,Synth.new(\delaySaxText, [\inBus, bus2, \outBus, bus3]));
		~saxTextNodes.insert(0,Synth.new(\lpSaxText, [\inBus, bus1, \outBus, bus2]));
		//"nodesAdded".postln;

		synth =  Synth.new(\playSaxText, [\outBus, busses[busIndex], \buf, ~b0, \amp, 0]);
		~saxTextNodes.insert(0,synth);

		SystemClock.sched(1, {
			var amp = 0.2.rand + 0.05;
			("amp:"++amp).postln;
			synth.set(\amp, amp);

			if(~playText[cont].not){
				"EXITING".postln;
				synth.set(\amp, 0);
				nil;
			}{
				3 + 2.0.rand;};
		});
	};


	~playText = Array.fill(10, {true});
}
)

~playText.size.do({arg i; ~playText[i] = true;});
//cue
~sched.value(3,0);

//cue
~playText[0] = false;
~sched.value(0,1);

//cue
~sched.value(1,2);

//cue
~sched.value(0,1);
~sched.value(1,2);

~playText.size.do({arg i; ~playText[i] = false;});

~saxTextNodes.size.do({arg i; ~saxTextNodes.free;});
