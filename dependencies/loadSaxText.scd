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
		sig = sig.madd(~amp);
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

	s.sync;
	~saxTextBuffs = [Buffer.read(s,Document.current.dir ++ "/dependencies/samples/sax1.wav"),
		Buffer.read(s,Document.current.dir ++ "/dependencies/samples/sax2.wav"),
		Buffer.read(s,Document.current.dir ++ "/dependencies/samples/sax5.wav")
	];
	s.sync;


	~saxTextNodes = List.new(8);

	~sched = {
		arg busIndex, cont, bufIndex = 0;
		var synth,
		bus1 = Bus.audio(s,1), bus2 = Bus.audio(s,1), bus3 = Bus.audio(s,1), bus4 = Bus.audio(s,1),
		busses = [bus1,bus2,bus3,bus4];
		//"addingNodes".postln;

		~saxTextNodes.insert(0,Synth.new(\autoPan, [\inBus, bus4, \outBus, 0, \rand, 3.0.rand]));
		~saxTextNodes.insert(0,Synth.new(\holdReverbSaxText, [\inBus, bus3, \outBus, bus4]));
		~saxTextNodes.insert(0,Synth.new(\delaySaxText, [\inBus, bus2, \outBus, bus3]));
		~saxTextNodes.insert(0,Synth.new(\lpSaxText, [\inBus, bus1, \outBus, bus2]));
		//"nodesAdded".postln;

		synth =  Synth.new(\playSaxText, [\outBus, busses[busIndex], \buf, ~saxTextBuffs[bufIndex], \amp, 0]);
		~saxTextNodes.insert(0,synth);
		if(cont == 0){synth.set(\amp, 1);};

		SystemClock.sched(1, {
			var amp = 0.5.rand + 0.1;
			if(cont == 0){amp = 0.5.rand + 0.5.rand};//much louder for unprocessed version
			("amp:"++amp++"for cont" ++ cont).postln;
			synth.set(\amp, amp);

			if(~playText[cont].not){
				("EXITING CONT" + cont).postln;
				synth.set(\amp, 0);
				{
					~saxTextNodes.do({arg node; node.free});
					busses.do({arg bus; bus.free});
				}.defer(30);
				nil;
			}{3 + 2.0.rand;};
		});
	};


	~bufIndexes = [3,0,1,0,1];
	~playText = Array.fill(~bufIndexes.size, {false});
}
)
// ~playText[0] = true;
// ~sched.value(0,0,0);
//
// ~playText[1] = true;
// ~sched.value(0,1,0);

