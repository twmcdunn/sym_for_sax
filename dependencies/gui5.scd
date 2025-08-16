(
~scoreDisplay = {
	var window, scoreView, eqButton, statusView, controlsView, titleView;
	var scoreImages, currentPage = 0, halfPageOffset = 0;
	var imagePath, imageWidth, imageHeight;
	var eqActive = false;

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

	// Hook for EQ integration - replace this function with your EQ GUI code
	var showEQWindow = {
		"EQ window hook - implement your EQ GUI here".postln;
		// Your EQ GUI code goes here
		// This function should create/show your EQ interface
		// You can access eqActive variable to track EQ state
	};

	// Hook for cue activation - replace with your cue handling code
	var activateCue = { |letter|
		("Cue activated: " ++ letter).postln;
		// Your cue activation code goes here
		// The 'letter' parameter contains the pressed key (a-z)
	};

	// Load score images
	var loadImages = {
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
	var updateScoreDisplay = {
		scoreView.refresh;
		statusView.string = "Page " ++ (currentPage + 1) ++ " of " ++ numPages ++
		                   "  •  Half " ++ (halfPageOffset + 1) ++ " of 2" ++
		                   "  •  EQ " ++ if(eqActive, "ACTIVE", "OFF");
	};
	var windowWidth;
	var windowHeight;
	var accentView;
	// Control panel background
	var controlPanelRect;
	var controlPanel;

	// Load images first
	loadImages.value;

	// Create main window with elegant proportions
	 windowWidth = imageWidth * 2 + 120;
	 windowHeight = imageHeight + 200;

	window = Window("Score Display", Rect(100, 100, windowWidth, windowHeight))
		.background_(bgColor)
		.front
		.onClose_({
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
	 controlPanelRect = Rect(20, imageHeight + 70, windowWidth - 40, 120);
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

	// Create elegant EQ button
	eqButton = Button(window, Rect(40, imageHeight + 90, 100, 35))
		.states_([
			["EQ OFF", textColor, buttonOffColor],
			["EQ ON", Color.white, buttonOnColor]
		])
		.font_(Font("Helvetica", 12, bold: true))
		.action_({ |button|
			("EQ button pressed, value:" + button.value).postln; // Debug
			eqActive = button.value == 1;
			if (eqActive) {
				showEQWindow.value;
			};
			updateScoreDisplay.value;
		});

	// Create status display with better typography
	statusView = StaticText(window, Rect(160, imageHeight + 85, windowWidth - 200, 25))
		.string_("Ready")
		.font_(Font("Helvetica", 13))
		.stringColor_(textColor)
		.background_(Color.clear);

	// Create controls instructions
	controlsView = StaticText(window, Rect(40, imageHeight + 115, windowWidth - 80, 65))
		.string_("CONTROLS: SPACE advance • SHIFT+SPACE back • ← → full page • A-Z cues • ESC close")
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

	// Set up keyboard handling
	window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
		("Key pressed - char:" + char + "keycode:" + keycode + "modifiers:" + modifiers).postln; // Debug

		case
		// Space bar - advance half page
		{ char == 32 } { // Space character
			if (halfPageOffset == 0) {
				halfPageOffset = 1;
			} {
				halfPageOffset = 0;
				currentPage = (currentPage + 1) % numPages;
			};
			updateScoreDisplay.value;
		}
		// Shift+Space - go back half page
		{ (char == 32) && (modifiers.bitAnd(131072) != 0) } { // Shift modifier
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
			activateCue.value(char.asString.toLower);
		}
		// Arrow keys for manual navigation
		{ keycode == 16777234 } { // Left arrow (Qt keycode)
			currentPage = (currentPage - 1 + numPages) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		{ keycode == 16777236 } { // Right arrow (Qt keycode)
			currentPage = (currentPage + 1) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		// ESC to close
		{ keycode == 16777216 } { // Escape (Qt keycode)
			window.close;
		};

		true; // Return true to indicate we handled the key
	};

	// Make sure the window can receive keyboard events
	window.view.canFocus = true;
	window.view.focus;

	// Alternative: Try setting focus on the window itself
	window.front;
	AppClock.sched(0.1, {
		window.view.focus;
		nil;
	});

	// Initial display update
	updateScoreDisplay.value;

	// Return the window for external access
	window;
};

// Usage instructions
"
Enhanced Score Display GUI
==========================
A visually elegant score display system with integrated controls.

Setup:
- Modify scorePath, imageExtension, and numPages variables
- Replace showEQWindow and activateCue hook functions
- Images should be named: page_01.jp2, page_02.jp2, etc.

The interface includes all control instructions and features
a modern dark theme with subtle visual accents.
".postln;

~scoreWindow = ~scoreDisplay.value;
)