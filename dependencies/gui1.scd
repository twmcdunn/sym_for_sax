(
// Portable Score Display GUI - Multiple Options
var window, mainView, currentPage = 0, halfPageOffset = 0;
var numPages, scoreContent, cueDict, statusText;
var scoreType = image; // Options: \text, \image, \hybrid
var imageFiles;

// Configuration
numPages = 8; // Number of score pages/sections

// Option 1: Text-based score content (most portable)
scoreContent = [
    "MOVEMENT I - Andante\n\nMeasures 1-16:\nStrings enter pp, sustained notes\nWoodwinds join at m. 8\n\n[Cue A] - Brass entrance\n[Cue B] - Dynamics to mf\n\nTempo marking: ♩ = 60",

    "Measures 17-32:\nString pizzicato section\nPercussion enters with triangle\n\n[Cue C] - Flute solo begins\n[Cue D] - Full ensemble\n\nRit. into next section",

    "MOVEMENT II - Allegro\n\nMeasures 33-48:\nFast sixteenth note passages\nStrings: arco, forte\n\n[Cue E] - Brass fanfare\n[Cue F] - Percussion break\n\nTempo: ♩ = 120",

    "Measures 49-64:\nDevelopment section\nModulation to G major\n\n[Cue G] - Solo violin\n[Cue H] - Tutti climax\n\nDiminuendo to pianissimo",

    "MOVEMENT III - Presto\n\nMeasures 65-80:\nScherzo section\nSyncopated rhythms\n\n[Cue I] - Woodwind choir\n[Cue J] - String tremolo\n\nAccel. gradually",

    "Measures 81-96:\nTrio section\nLyrical melody in cellos\n\n[Cue K] - Horn calls\n[Cue L] - Return to Scherzo\n\nDa Capo al Fine",

    "FINALE - Maestoso\n\nMeasures 97-112:\nGrand finale begins\nFull orchestra fortissimo\n\n[Cue M] - Final climax\n[Cue N] - Closing cadence\n\nRallentando molto",

    "Coda:\nFinal measures\nAll instruments unison\n\n[Cue O] - Last chord\n[Cue P] - Fermata\n\nEnd of piece"
];

// Alternative: Image file paths (if you have pre-converted images)
imageFiles = [
"/Users/maestro/Documents/Coding/innerSoundScape3/resources/imgScore/output.jp2",
"/Users/maestro/Documents/Coding/innerSoundScape3/resources/imgScore/output1.jp2"
];

// Cue dictionary - map letters to functions
cueDict = Dictionary.newFrom([
    $a, { "Cue A: Brass entrance".postln; /* Add your synth/sample code */ },
    $b, { "Cue B: Dynamics to mf".postln; },
    $c, { "Cue C: Flute solo begins".postln; },
    $d, { "Cue D: Full ensemble".postln; },
    $e, { "Cue E: Brass fanfare".postln; },
    $f, { "Cue F: Percussion break".postln; },
    $g, { "Cue G: Solo violin".postln; },
    $h, { "Cue H: Tutti climax".postln; },
    $i, { "Cue I: Woodwind choir".postln; },
    $j, { "Cue J: String tremolo".postln; },
    $k, { "Cue K: Horn calls".postln; },
    $l, { "Cue L: Return to Scherzo".postln; },
    $m, { "Cue M: Final climax".postln; },
    $n, { "Cue N: Closing cadence".postln; },
    $o, { "Cue O: Last chord".postln; },
    $p, { "Cue P: Fermata".postln; }
]);

// Function to display current content
~displayContent = {
    var content, pageIndex;

    // Calculate which content to show based on page and half-page offset
    pageIndex = (currentPage * 2) + halfPageOffset;
    pageIndex = pageIndex.min(scoreContent.size - 1);

    content = scoreContent[pageIndex] ? "End of score";

    case
    { scoreType == \text } {
        mainView.string = content;
        statusText.string = "Page: " ++ (currentPage + 1) ++
                           ", Half: " ++ (halfPageOffset + 1) ++
                           " | SPACE: next half-page, SHIFT+SPACE: previous, A-P: cues";
    }
    { scoreType == \image } {
        // Load image if available
        if(imageFiles.size > pageIndex and: { File.exists(imageFiles[pageIndex].standardizePath) }, {
            var image = Image.open(imageFiles[pageIndex].standardizePath);
            mainView.setImage(image);
            statusText.string = "Image Page: " ++ (pageIndex + 1) ++ " | Controls: SPACE, SHIFT+SPACE, A-P";
        }, {
            mainView.string = "Image not found: " ++ (imageFiles[pageIndex] ? "No image specified");
        });
    };

    ("Displaying page" + (currentPage + 1) + "half" + (halfPageOffset + 1)).postln;
};

// Navigation functions
~advanceHalfPage = {
    if(halfPageOffset == 0, {
        halfPageOffset = 1;
    }, {
        halfPageOffset = 0;
        currentPage = (currentPage + 1).min(((scoreContent.size - 1) / 2).floor);
    });
    ~displayContent.();
};

~goBackHalfPage = {
    if(halfPageOffset == 1, {
        halfPageOffset = 0;
    }, {
        halfPageOffset = 1;
        currentPage = (currentPage - 1).max(0);
    });
    ~displayContent.();
};

// Create main window
window = Window("Portable Score Display", Rect(200, 100, 900, 700))
    .background_(Color.gray(0.1))
    .onClose_({ "Score display closed".postln; });

// Create main content view (text or image)
case
{ scoreType == \text } {
    mainView = TextView(window, Rect(20, 20, 860, 580))
        .background_(Color.gray(0.9))
        .stringColor_(Color.black)
        .font_(Font("Monaco", 14))
        .editable_(false)
        .resize_(5);
}
{ scoreType == \image } {
    mainView = UserView(window, Rect(20, 20, 860, 580))
        .background_(Color.gray(0.2))
        .resize_(5);
};

// Status bar
statusText = StaticText(window, Rect(20, 610, 860, 25))
    .background_(Color.black)
    .stringColor_(Color.white)
    .font_(Font("Arial", 11));

// Instructions
StaticText(window, Rect(20, 640, 860, 35))
    .string_("CONTROLS: SPACE = next half-page | SHIFT+SPACE = previous | A-P = trigger cues | ESC = close")
    .stringColor_(Color.yellow)
    .background_(Color.black)
    .font_(Font("Arial", 10));

// Key handling
window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    case
    { char == $ } { // Space
        if(modifiers.isShift, {
            ~goBackHalfPage.();
        }, {
            ~advanceHalfPage.();
        });
    }
    { char == 27.asAscii } { // Escape
        window.close;
    }
    { char.isAlpha } { // Letters A-Z
        var lowerChar = char.toLower;
        var cueFunc = cueDict[lowerChar];
        if(cueFunc.notNil, {
            cueFunc.();
            statusText.stringColor = Color.green;
            defer({ statusText.stringColor = Color.white; }, 0.5);
        }, {
            ("No cue defined for: " ++ char.toUpper).postln;
        });
    }
    { keycode == 123 } { // Left arrow - previous half page
        ~goBackHalfPage.();
    }
    { keycode == 124 } { // Right arrow - next half page
        ~advanceHalfPage.();
    };
};

// Enable keyboard focus
window.view.canFocus = true;
window.view.focus;

// Show window and load first content
window.front;
~displayContent.();

// Store reference
~scoreWindow = window;

// Instructions for setup
"\n=== SETUP INSTRUCTIONS ===".postln;
"1. CURRENT MODE: Text-based score (fully portable)".postln;
"2. TO USE IMAGES: Set scoreType = \\image and add image paths to imageFiles array".postln;
"3. CUSTOMIZE: Edit scoreContent array with your score sections".postln;
"4. CUES: Modify cueDict functions to trigger your sounds/synths".postln;
"=============================\n".postln;
)