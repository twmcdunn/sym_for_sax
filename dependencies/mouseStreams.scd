(
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
	p.pause;
	~mouseStreams[n] = p;
}
);
)