(
/*SynthDef.new(\harmonizer, {
arg inbus = 4;
var sig, midi, pc, harm, freq, hasFreq, harmarr = [[-2,-6,-9],[-4,-6,-9],[-3,-5,-9],[-3,-7,-9],[-3,-6,-8],[-3,-6,-10],[-2,-5,-8],[-3,-7,-10]], octMember = [0,1,0,2,3,0,4,5,0,6,7,0], oct;
sig = In.ar(inbus,2);
sig = Mix.ar(sig);
# freq, hasFreq = Pitch.kr(sig);
midi = freq.cpsmidi.round;
//mod 12
oct = (midi / 12).floor;
pc = midi - (oct * 12);

octMember.do({arg memb, i;
harmarr.do({arg arr;
harm[i] = Mix.ar([
PitchShift.ar(sig, pitchRatio: intervals.midiratio),
]);
});
});

sig = Mix.ar([sig,Select.ar(pc, harm)]);

Out.ar(0, sig);
}).add;*/

SynthDef.new(\harmonizer, {
	arg inbus = 4, outBus = 6, scaleIndex = 0, harmArrIndex = 0;
	var sig, midi, pc, harm, freq, hasFreq,
	harmarrs = [
		[[-2,-6,-9],[-4,-6,-9],[-3,-5,-9],[-3,-7,-9],[-3,-6,-8],[-3,-6,-10],[-2,-5,-8],[-3,-7,-10]],
		[[-3,-6,-9]],
	], harmArr,
	scaleMember, scales = [[0,1,0,2,3,0,4,5,0,6,7,0], [0,0,1,0,2,3,0,4,5,0,6,7],[7,0,0,1,0,2,3,0,4,5,0,6],Array.fill(12,{0})],
	oct, harmIndex, intervals;

	sig = In.ar(inbus,2);
	sig = Mix.ar(sig);
	# freq, hasFreq = Pitch.kr(sig);
	midi = freq.cpsmidi.round;

	// mod 12
	oct = (midi / 12).floor;
	pc = midi - (oct * 12);

	// Map pitch class to octatonic scale degree
	scaleMember = Select.kr(scaleIndex, scales);
	harmIndex = Select.kr(pc, scaleMember);

	/*// Build harmonizer signals for each octatonic degree
	harm = harmarr.collect({arg intervals, deg;
	Mix.ar(intervals.collect({arg interval;
	PitchShift.ar(sig, pitchRatio: interval.midiratio);
	}));
	});*/
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

SynthDef.new(\thru, {
	arg inBus = 7, outBus = 0;
	var sig;
	sig = In.ar(inBus,1);
	Out.ar(outBus, sig.dup);
}).add;

SynthDef.new(\play, {
	arg bus = 4, buff = 0;
	Out.ar(bus,PlayBuf.ar(2,buff,BufRateScale.kr(buff)));
}).add;

/*SynthDef.new(\delay, {
arg inBus = 4, outBus = 4, delayTime = 0.5, decayTime = 3;
var sig = In.ar(inBus, 1);
sig = CombC.ar(sig, delayTime,delayTime,decayTime).madd(0.5 * SinOsc.ar(1/5.0,0,0.5,1));
//sig = Mix.ar(sig);
Out.ar(outBus,Pan2.ar(sig,SinOsc.ar(1/(3.0.rand + 2.0))));
}).add;*/

~play = {
	arg buff;
	{PlayBuf.ar(2,buff, BufRateScale.kr(buff))}.play;
};

)

(
fork{
	~b1 = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/melodyTemplate.wav");
	~b2 = Buffer.read(s,"/Users/maestro/Documents/Coding/innerSoundScape3/saxTexture.wav");
	s.sync;
	c = Synth.new(\thru);
	b = Synth.new(\reverb);
	a = Synth.new(\harmonizer);
	d = Synth.new(\play,[\buff,~b1]);

	{a.set(\scaleIndex,1); "trans changed".postln;}.defer(15);
	{a.set([\scaleIndex,3,\harmArrIndex, 1])}.defer(31);
	{a.set([\scaleIndex,0,\harmArrIndex, 0]); "trans changed".postln;}.defer(40);
	{a.set([\scaleIndex,1,\harmArrIndex, 0]); "trans changed".postln;}.defer(54);
	{a.set([\scaleIndex,0,\harmArrIndex, 0]); "trans changed".postln;}.defer(58.5);


	/*{PlayBuf.ar(2,~b1 * Buff)}.play;
	{PlayBuf.ar(2,~b2)}.play;*/
	~play.(~b1);
	~play.(~b2);
};
)

//metallic swell

{"hi".postln}.defer(2);

~play.value(~b2);

(
fork{
	a = Synth.new(\harmonizer);
	s.sync;
	b = Synth.new(\play,[\buff,~b0]);
}
)
~arr = [1,2]
~arr.wrapAt(2)
//438 hz sax loop
3.0.asInt
a

-1.midiratio