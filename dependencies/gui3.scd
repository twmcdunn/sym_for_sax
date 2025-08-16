(
~scoreDisplay = {
	var window, scoreView, eqButton, statusView;
	var scoreImages, currentPage = 0, halfPageOffset = 0;
	var imagePath, imageWidth, imageHeight;
	var eqActive = false;

	// Configuration - modify these paths as needed
	var scorePath = 	"/Users/maestro/Documents/Coding/innerSoundScape3/resources/imgScore/"; // Path to your score images
	var imageExtension = ".jp2"; // or ".jpg", ".tiff", etc.
	var numPages = 2; // Total number of score pages

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
				// Create a placeholder image
				scoreImages[i] = Image.color(800, 600, Color.gray(0.9));
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
		statusView.string = "Page: " ++ (currentPage + 1) ++ "/" ++ numPages ++
		                   " | Half-page: " ++ (halfPageOffset + 1) ++ "/2" ++
		                   " | EQ: " ++ if(eqActive, "ON", "OFF");
	};

	// Load images first
	loadImages.value;

	// Create main window
	window = Window("Score Display", Rect(100, 100, imageWidth * 2 + 100, imageHeight + 100))
		.front
		.onClose_({
			"Score display closed".postln;
		});

	// Create score display view
	scoreView = UserView(window, Rect(50, 20, imageWidth * 2, imageHeight))
		.background_(Color.black)
		.drawFunc_({
			var currentImage = scoreImages[currentPage];
			if (currentImage.notNil) {
				var drawRect = Rect(0, 0, imageWidth * 2, imageHeight);

				// If we're showing the second half of the page, offset the source rectangle
				if (halfPageOffset == 1) {
					var sourceRect = Rect(0, imageHeight * 0.5, imageWidth, imageHeight * 0.5);
					var destRect = Rect(0, 0, imageWidth * 2, imageHeight);
					currentImage.drawInRect(destRect, sourceRect);
				} {
					// Show first half or full page
					var sourceRect = Rect(0, 0, imageWidth, imageHeight * 0.5);
					var destRect = Rect(0, 0, imageWidth * 2, imageHeight);
					currentImage.drawInRect(destRect, sourceRect);
				};
			};
		});

	// Create EQ button
	eqButton = Button(window, Rect(20, imageHeight + 30, 80, 25))
		.states_([
			["EQ OFF", Color.black, Color.gray(0.8)],
			["EQ ON", Color.white, Color.blue]
		])
		.action_({ |button|
			eqActive = button.value == 1;
			if (eqActive) {
				showEQWindow.value;
			};
			updateScoreDisplay.value;
		});

	// Create status display
	statusView = StaticText(window, Rect(110, imageHeight + 30, 400, 25))
		.string_("Ready")
		.font_(Font.monospace(12));

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
		{ keycode == 65361 } { // Left arrow
			currentPage = (currentPage - 1 + numPages) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		{ keycode == 65363 } { // Right arrow
			currentPage = (currentPage + 1) % numPages;
			halfPageOffset = 0;
			updateScoreDisplay.value;
		}
		// ESC to close
		{ keycode == 65307 } {
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
Score Display GUI Usage:
========================

1. Modify the configuration variables at the top:
   - scorePath: path to your score images folder
   - imageExtension: file extension of your images
   - numPages: total number of score pages

2. Replace the hook functions:
   - showEQWindow: implement your EQ GUI creation/display code
   - activateCue: implement your cue activation code

3. Image naming convention:
   Images should be named: page_01.png, page_02.png, etc.

4. Controls:
   - SPACE: advance half page
   - SHIFT+SPACE: go back half page
   - LEFT/RIGHT arrows: full page navigation
   - A-Z keys: activate cues
   - EQ button: toggle EQ (calls your EQ GUI)
   - ESC: close window

5. To start the GUI:
   ~scoreWindow = ~scoreDisplay.value;
".postln;
~scoreWindow = ~scoreDisplay.value;
)


