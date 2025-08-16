(
{
	// Elegant Elapsed Time Display
	var timeView, startTime, updateRoutine;

	// Initialize start time
	startTime = Main.elapsedTime;

	// Time display with elegant styling
	timeView = StaticText(window, Rect(windowWidth - 320, imageHeight/4 + 85, 280, 100))
	.string_("00:00:00.0")
	.font_(Font("Monaco", 24))
	.stringColor_(Color.white)
	.align_(\center)
	.background_(Color.gray(0.1));


	// Format time function
	~formatTime = { |seconds|
		var hours, mins, secs, tenths;
		hours = (seconds / 3600).floor;
		mins = ((seconds % 3600) / 60).floor;
		secs = (seconds % 60).floor;
		tenths = ((seconds % 1) * 10).floor;
		"%.%.%.%".format(
			hours.asInteger.asString.padLeft(2, "0"),
			mins.asInteger.asString.padLeft(2, "0"),
			secs.asInteger.asString.padLeft(2, "0"),
			tenths.asInteger.asString//.padLeft(2, "0")
		);
	};

	// Update routine
	updateRoutine = Routine({
		loop {
			var elapsed = Main.elapsedTime - startTime;
			timeView.string_(~formatTime.(elapsed));
			0.1.wait;
		}
	}).play(AppClock);

	// Cleanup on window close
	window.onClose_({
		updateRoutine.stop;
		"Timer closed".postln;
	});

	// Show window
	window.front;

	// Return a function to restart the timer programmatically
	~restartTimer = {
		startTime = Main.elapsedTime;
		"Timer restarted programmatically".postln;
	};

	~getTime = {
		Main.elapsedTime - startTime;
	};
}.value;
)