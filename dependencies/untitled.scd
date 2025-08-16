(
~burst = {
	arg buffFreqs = ~buffFreqs, hold = 0, oct = 0, ampFactor = 1, trans = 0, scale = Scale.diminished.degrees;
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
		}.defer(30);
	}
	{2}{
		var holdInst1, holdInst2, del1, del2, revBus, bus1, bus2, dels = [];
		instOutBus = Bus.audio(s,2);
		revBus = Bus.audio(s,2);
		bus1 = Bus.audio(s,2);
		bus2 = Bus.audio(s,2);

		del1 = Synth.new(\delay, [\inBus, bus2, \outBus, 0]);
		del2 = Synth.new(\delay, [\inBus, bus2.index + 1, \outBus, 1]);
		dels = dels.add(del1,del2);
		3.do({
			del1 = Synth.new(\delay, [\inBus, bus1, \outBus, bus2]);
			del2 = Synth.new(\delay, [\inBus, bus1.index + 1, \outBus, bus2.index + 1]);
			dels = dels.add(del1,del2);
			bus2 = bus1;
			bus1 = Bus.audio(s,2);
		});

		holdInst1 = Synth.new(\reverb, [\inBus,instOutBus,\outBus, bus2]);//bu2 is old bus1
		holdInst2 = Synth.new(\reverb, [\inBus,instOutBus.index + 1,\outBus, bus2.index + 1]);

		{
			holdInst1.free;
			holdInst2.free;
			dels.do({arg del; del.free});
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
				dur = dur * 1.03;
			}
		}),
		\amp, Routine({
			while{amp < 1}{
				(amp * ampFactor).yield;
				amp = amp * 1.1;
				amp = 1.min(amp);
			};
			decaying = true;
			amp = 1;
			loop{
				(amp * ampFactor).yield;
				amp = amp * 0.985;//* 0.98;
			}
		}),
		\outBus, instOutBus
	).play;
};

~burst1 = {
	arg buffFreqs = ~buffFreqs, hold = 0, oct = 0, ampFactor = 1, trans = 0, scale = Scale.diminished.degrees;
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
		}.defer(30);
	}
	{2}{
		var holdInst1, holdInst2, del1, del2, revBus, bus1, bus2, dels = [];
		instOutBus = Bus.audio(s,2);
		revBus = Bus.audio(s,2);
		bus1 = Bus.audio(s,2);
		bus2 = Bus.audio(s,2);

		del1 = Synth.new(\delay, [\inBus, bus2, \outBus, 0]);
		del2 = Synth.new(\delay, [\inBus, bus2.index + 1, \outBus, 1]);
		dels = dels.add(del1,del2);
		3.do({
			del1 = Synth.new(\delay, [\inBus, bus1, \outBus, bus2]);
			del2 = Synth.new(\delay, [\inBus, bus1.index + 1, \outBus, bus2.index + 1]);
			dels = dels.add(del1,del2);
			bus2 = bus1;
			bus1 = Bus.audio(s,2);
		});

		holdInst1 = Synth.new(\reverb, [\inBus,instOutBus,\outBus, bus2]);//bu2 is old bus1
		holdInst2 = Synth.new(\reverb, [\inBus,instOutBus.index + 1,\outBus, bus2.index + 1]);

		{
			holdInst1.free;
			holdInst2.free;
			dels.do({arg del; del.free});
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
				dur = dur * 1.03;
			}
		}),
		\amp, Routine({
			while{amp < 1}{
				(amp * ampFactor).yield;
				amp = amp / 0.985;
				amp = 1.min(amp);
			};
			decaying = true;
			amp = 1;
			loop{
				(amp * ampFactor).yield;
				amp = amp * 0.985;//* 0.98;
			}
		}),
		\outBus, instOutBus
	).play;
};
)
~burst1.value