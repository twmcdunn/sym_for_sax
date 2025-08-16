(
~scoreDisplay = {
	var window, scoreView, eqButton, statusView, controlsView, titleView;
	var scoreImages, currentPage = 0, halfPageOffset = 0;
	var imagePath, imageWidth, imageHeight;
	var eqActive = false;
	var windowWidth, windowHeight, controlPanelRect, controlPanel, accentView;

	// EQ variables
	var eqSynth, eqView, eqValueArr, eqPlotter, eqVisible = false;
	var inBus = 9, outBus = 10;

	// Configuration - modify these paths as needed
	var scorePath = "/Users/maestro/Documents/Coding/innerSoundScape3/resources/imgScore/"; // Path to your score images
	var imageExtension = ".jp2"; // or ".jpg", ".tiff", etc.
	var numPages = 2; // Total number of score pages

	// Color scheme for elegant appearance
	var bgColor = Color.gray(0.15);
	var panelColor = Color.gray(0.2);
	var accentColor = Color(0.3, 0.6, 0.9);
	var textColor = Color.gray(0.9);
	var buttonOffColor = Color.gray(0.25);
	var buttonOnColor = accentColor;

	var showEQWindow;
	var activateCue;
	var updateScoreDisplay;
	var loadImages;

	// EQ Functions
	var bezier, buildCurv, setSyntVals, initEQ, showEQPanel, hideEQPanel;

	// Bezier curve calculation
	bezier = { |y1, y2, x1, x2|
		var p0, p1, p2, p3, xDist = x2 - x1, yDist = y2 - y1, plotArr, size = 50;
		p0 = [x1, y1];
		p1 = [x1 + (0.3 * xDist), 0];
		p2 = [x2 - (0.3 * xDist), 0];
		p3 = [x2, y2];

		plotArr = Array.fill(size, { |i|
			var t = i / size, quad1, quad2, cubic;
			quad1 = [((1-t).pow(2) * p0[0]) + (2 * (1-t) * t * p1[0]) + (t.pow(2) * p2[0]),
				((1-t).pow(2) * p0[1]) + (2 * (1-t) * t * p1[1]) + (t.pow(2) * p2[1])];
			quad2 = [((1-t).pow(2) * p1[0]) + (2 * (1-t) * t * p2[0]) + (t.pow(2) * p3[0]),
				((1-t).pow(2) * p1[1]) + (2 * (1-t) * t * p2[1]) + (t.pow(2) * p3[1])];
			cubic = [((1-t) * quad1[0]) + (t * quad2[0]),
				((1-t) * quad1[1]) + (t * quad2[1])];
			cubic;
		});
		plotArr;
	};

	// Build EQ curve
	buildCurv = { |data|
		var curv = List.new();
		(data.size - 1).do({ |i|
			var moreCurv = bezier.value(data[i][1], data[i+1][1], data[i][0], data[i+1][0]);
			moreCurv.do({ |pt| curv.add(pt); });
		});
		curv;
	};

	// Set synth values
	setSyntVals = {
		if (eqSynth.notNil) {
			eqSynth.set(
				\f1, eqValueArr[1][0], \f2, eqValueArr[2][0], \f3, eqValueArr[3][0], \f4, eqValueArr[4][0],
				\db1, eqValueArr[1][1], \db2, eqValueArr[2][1], \db3, eqValueArr[3][1], \db4, eqValueArr[4][1]
			);
		};
	};

	// Initialize EQ
	initEQ = {
		fork {
			eqValueArr = List.fill(6, { |i| [50 * 3.pow(i), 0] });

			SynthDef.new(\eq, {
				arg inBus, outBus, f1, f2, f3, f4, db1, db2, db3, db4;
				var inSig, outSig;
				inSig = In.ar(inBus, 1);
				outSig = inSig.madd(1/4.0);
				[[f1,db1],[f2,db2],[f3,db3],[f4,db4]].do({ |vals|
					outSig = MidEQ.ar(outSig, vals[0], 0.3, vals[1])
				});
				Out.ar(outBus, outSig);
			}).add;

			s.sync;

			eqSynth = Synth.tail(s, \eq, [
				\inBus, inBus, \outBus, outBus,
				\f1, eqValueArr[1][0], \f2, eqValueArr[2][0], \f3, eqValueArr[3][0], \f4, eqValueArr[4][0],
				\db1, eqValueArr[1][1], \db2, eqValueArr[2][1], \db3, eqValueArr[3][1], \db4, eqValueArr[4][1]
			]);

			eqValueArr.addFirst([20, -60]);
			eqValueArr.add([50000, -60]);
		};
	};

	// Show EQ panel
	showEQPanel = {
		if (eqView.isNil) {
			var eqRect = Rect(windowWidth - 320, imageHeight + 85, 280, 100);

			eqView = UserView(window, eqRect)
				.background_(Color.gray(0.18))
				.drawFunc_({
					var curv, eqRect = Rect(0, 0, 280, 100);
					var plotRect = Rect(10, 10, 260, 60);
					var controlRect = Rect(10, 75, 260, 20);

					// Draw EQ panel background
					Pen.fillColor = Color.gray(0.18);
					Pen.addRoundedRect(eqRect, 4, 4);
					Pen.fill;

					// Draw plot background
					Pen.fillColor = Color.black.alpha_(0.5);
					Pen.addRoundedRect(plotRect, 2, 2);
					Pen.fill;

					// Draw grid
					Pen.strokeColor = Color.gray(0.3);
					Pen.width = 0.5;
					5.do({ |i|
						var x = plotRect.left + (i * plotRect.width / 4);
						Pen.moveTo(Point(x, plotRect.top));
						Pen.lineTo(Point(x, plotRect.bottom));
					});
					3.do({ |i|
						var y = plotRect.top + (i * plotRect.height / 2);
						Pen.moveTo(Point(plotRect.left, y));
						Pen.lineTo(Point(plotRect.right, y));
					});
					Pen.stroke;

					// Draw EQ curve
					if (eqValueArr.notNil) {
						curv = buildCurv.value(eqValueArr);
						Pen.strokeColor = accentColor;
						Pen.width = 2;

						curv.do({ |pt, i|
							var x = plotRect.left + (pt[0].log10 - 20.log10) / (50000.log10 - 20.log10) * plotRect.width;
							var y = plotRect.bottom - ((pt[1] + 60) / 120 * plotRect.height);

							if (i == 0) {
								Pen.moveTo(Point(x, y));
							} {
								Pen.lineTo(Point(x, y));
							};
						});
						Pen.stroke;

						// Draw control points
						Pen.fillColor = accentColor;
						(1..4).do({ |i|
							var freq = eqValueArr[i][0];
							var gain = eqValueArr[i][1];
							var x = plotRect.left + (freq.log10 - 20.log10) / (50000.log10 - 20.log10) * plotRect.width;
							var y = plotRect.bottom - ((gain + 60) / 120 * plotRect.height);
							Pen.addOval(Rect(x-3, y-3, 6, 6));
							Pen.fill;
						});
					};

					// Draw labels
					Pen.stringColor = textColor;
					Pen.font = Font("Helvetica", 9);
					Pen.stringAtPoint("20Hz", Point(plotRect.left, plotRect.bottom + 5));
					Pen.stringAtPoint("20kHz", Point(plotRect.right - 30, plotRect.bottom + 5));
					Pen.stringAtPoint("+60dB", Point(plotRect.left - 35, plotRect.top));
					Pen.stringAtPoint("-60dB", Point(plotRect.left - 35, plotRect.bottom - 5));
					Pen.stringAtPoint("EQ Response", Point(plotRect.left, controlRect.top + 5));
				})
				.mouseDownAction_({ |view, x, y|
					var plotRect = Rect(10, 10, 260, 60);
					if (plotRect.contains(Point(x, y)) && eqValueArr.notNil) {
						// Find closest control point
						var minDist = inf, closestIdx = 1, newFreq, newGain;
						(1..4).do({ |i|
							var freq = eqValueArr[i][0];
							var gain = eqValueArr[i][1];
							var px = plotRect.left + (freq.log10 - 20.log10) / (50000.log10 - 20.log10) * plotRect.width;
							var py = plotRect.bottom - ((gain + 60) / 120 * plotRect.height);
							var dist = Point(x - px, y - py).rho;
							if (dist < minDist) {
								minDist = dist;
								closestIdx = i;
							};
						});

						// Update the closest point
						 newFreq = (20 * ((50000/20) ** ((x - plotRect.left) / plotRect.width))).clip(50, 25000);
						 newGain = (((plotRect.bottom - y) / plotRect.height) * 120 - 60).clip(-60, 60);

						eqValueArr[closestIdx][0] = newFreq;
						eqValueArr[closestIdx][1] = newGain;

						setSyntVals.value;
						eqView.refresh;
					};
				});
		};
		eqView.visible = true;
		eqVisible = true;
	};

	// Hide EQ panel
	hideEQPanel = {
		if (eqView.notNil) {
			eqView.visible = false;
		};
		eqVisible = false;
	};

	// Hook for EQ integration
	 showEQWindow = {
		if (eqVisible) {
			hideEQPanel.value;
		} {
			showEQPanel.value;
		};
	};

	// Hook for cue activation - replace with your cue handling code
	 activateCue = { |letter|
		("Cue activated: " ++ letter).postln;
		// Your cue activation code goes here
		// The 'letter' parameter contains the pressed key (a-z)
	};

	// Load score images
	 loadImages = {
		scoreImages = Array.newClear(numPages);
		numPages.do { |i|
			var imageName = "page_" ++ (i + 1).asString.padLeft(2, "0") ++ imageExtension;
			var fullPath = (scorePath ++ imageName).standardizePath;

			if (File.exists(fullPath)) {
				scoreImages[i] = Image.open(fullPath);
				("Loaded: " ++ imageName).postln;
			} {
				("Warning: Image not found - " ++ fullPath).postln;
				// Create a placeholder image with elegant styling
				scoreImages[i] = Image.color(800, 600, Color.gray(0.3));
			};
		};

		if (scoreImages[0].notNil) {
			imageWidth = scoreImages[0].width;
			imageHeight = scoreImages[0].height;
		} {
			imageWidth = 800;
			imageHeight = 600;
		};
	};

	// Update score display
	 updateScoreDisplay = {
		scoreView.refresh;
		statusView.string = "Page " ++ (currentPage + 1) ++ " of " ++ numPages ++
		                   "  •  Half " ++ (halfPageOffset + 1) ++ " of 2" ++
		                   "  •  EQ " ++ if(eqActive, "ACTIVE", "OFF");
	};

	// Load images first
	loadImages.value;

	// Initialize EQ
	initEQ.value;

	// Create main window with elegant proportions
	windowWidth = imageWidth * 2 + 120;
	windowHeight = imageHeight + 200;

	window = Window("Score Display", Rect(100, 100, windowWidth, windowHeight))
		.background_(bgColor)
		.front
		.onClose_({
			if (eqSynth.notNil) { eqSynth.free; };
			"Score display closed".postln;
		});

	// Create title bar
	titleView = StaticText(window, Rect(0, 10, windowWidth, 30))
		.string_("Score Display")
		.font_(Font("Helvetica", 18, bold: true))
		.stringColor_(textColor)
		.background_(Color.clear)
		.align_(\center);

	// Create score display view with subtle border
	scoreView = UserView(window, Rect(60, 50, imageWidth * 2, imageHeight))
		.background_(Color.black)
		.drawFunc_({
			var currentImage = scoreImages[currentPage];

			// Draw subtle border
			Pen.strokeColor = Color.gray(0.4);
			Pen.strokeRect(Rect(0, 0, imageWidth * 2, imageHeight));

			if (currentImage.notNil) {
				// If we're showing the second half of the page, offset the source rectangle
				if (halfPageOffset == 1) {
					var sourceRect = Rect(0, imageHeight * 0.5, imageWidth, imageHeight * 0.5);
					var destRect = Rect(2, 2, imageWidth * 2 - 4, imageHeight - 4);
					currentImage.drawInRect(destRect, sourceRect);
				} {
					// Show first half or full page
					var sourceRect = Rect(0, 0, imageWidth, imageHeight * 0.5);
					var destRect = Rect(2, 2, imageWidth * 2 - 4, imageHeight - 4);
					currentImage.drawInRect(destRect, sourceRect);
				};
			};
		});

	// Control panel background
	controlPanelRect = Rect(20, imageHeight + 70, windowWidth - 40, 110);
	controlPanel = UserView(window, controlPanelRect)
		.background_(panelColor)
		.drawFunc_({
			// Draw rounded rectangle background
			Pen.fillColor = panelColor;
			Pen.addRoundedRect(Rect(0, 0, controlPanelRect.width, controlPanelRect.height), 8, 8);
			Pen.fill;

			// Draw subtle border
			Pen.strokeColor = Color.gray(0.35);
			Pen.addRoundedRect(Rect(0, 0, controlPanelRect.width, controlPanelRect.height), 8, 8);
			Pen.stroke;
		});

	// Create status display with better typography
	statusView = StaticText(window, Rect(160, imageHeight + 85, windowWidth - 200, 25))
		.string_("Ready")
		.font_(Font("Helvetica", 13))
		.stringColor_(textColor)
		.background_(Color.clear);

	// Create controls instructions
	controlsView = StaticText(window, Rect(40, imageHeight + 115, windowWidth - 80, 65))
		.string_("CONTROLS: SPACE advance • ← → advance or go back • A-Z cues • ESC close")
		.font_(Font("Helvetica", 11))
		.stringColor_(Color.gray(0.7))
		.background_(Color.clear)
		.align_(\left);

	// Add some visual flourishes - corner accents
	accentView = UserView(window, Rect(0, 0, windowWidth, windowHeight))
		.background_(Color.clear)
		.drawFunc_({
			var cornerSize = 3;
			var cornerLength = 20;

			Pen.strokeColor = accentColor;
			Pen.width = cornerSize;

			// Top left corner
			Pen.moveTo(Point(15, 15 + cornerLength));
			Pen.lineTo(Point(15, 15));
			Pen.lineTo(Point(15 + cornerLength, 15));

			// Top right corner
			Pen.moveTo(Point(windowWidth - 15 - cornerLength, 15));
			Pen.lineTo(Point(windowWidth - 15, 15));
			Pen.lineTo(Point(windowWidth - 15, 15 + cornerLength));

			// Bottom left corner
			Pen.moveTo(Point(15, windowHeight - 15 - cornerLength));
			Pen.lineTo(Point(15, windowHeight - 15));
			Pen.lineTo(Point(15 + cornerLength, windowHeight - 15));

			// Bottom right corner
			Pen.moveTo(Point(windowWidth - 15 - cornerLength, windowHeight - 15));
			Pen.lineTo(Point(windowWidth - 15, windowHeight - 15));
			Pen.lineTo(Point(windowWidth - 15, windowHeight - 15 - cornerLength));

			Pen.stroke;
		});

	// Create elegant EQ button
	eqButton = Button(window, Rect(40, imageHeight + 90, 100, 35))
		.states_([
			["EQ OFF", textColor, buttonOffColor],
			["EQ ON", Color.white, buttonOnColor]
		])
		.font_(Font("Helvetica", 12, bold: true))
		.action_({ |button|
			eqActive = button.value == 1;
			if (eqActive) {
				showEQWindow.value;
			} {
				hideEQPanel.value;
			};
			updateScoreDisplay.value;
		});

	// Set up keyboard handling
	window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
		case
		// Space bar - advance half page
		{ char == $ } {
			if (halfPageOffset == 0) {
				halfPageOffset = 1;
			} {
				halfPageOffset = 0;
				currentPage = (currentPage + 1) % numPages;
			};
			updateScoreDisplay.value;
		}
		// Shift+Space - go back half page
		{ (char == $ ) && (modifiers & 131072 != 0) } {
			if (halfPageOffset == 1) {
				halfPageOffset = 0;
			} {
				halfPageOffset = 1;
				currentPage = (currentPage - 1 + numPages) % numPages;
			};
			updateScoreDisplay.value;
		}
		// Letters a-z - activate cues
		{ char.isAlpha } {
			activateCue.value(char.toLower);
		}
		// Arrow keys for manual navigation
		{ keycode == 123 } { // Left arrow
			currentPage = (currentPage - 1 + numPages) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		{ keycode == 124 } { // Right arrow
			currentPage = (currentPage + 1) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		// ESC to close
		{ keycode == 53 } {
			window.close;
		};
	};

	// Make sure the window can receive keyboard events
	window.view.canFocus = true;
	window.view.focus;

	// Initial display update
	updateScoreDisplay.value;

	// Return the window for external access
	window;
};

// Usage instructions
"
Enhanced Score Display GUI with Integrated EQ
=============================================
A visually elegant score display system with integrated 4-band EQ.

Setup:
- Modify scorePath, imageExtension, and numPages variables
- Replace activateCue hook function for your cue system
- Images should be named: page_01.jp2, page_02.jp2, etc.

EQ Controls:
- Click EQ button to show/hide EQ panel
- Click and drag on the curve control points to adjust frequency and gain
- EQ processes audio from bus 9 to bus 10

The interface features a modern dark theme with direct curve manipulation.
".postln;

~scoreWindow = ~scoreDisplay.value;
)