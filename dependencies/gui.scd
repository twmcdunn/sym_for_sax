(
// PDF Score Display GUI with Navigation and Cues
var window, imageView, currentPage = 0, halfPageOffset = 0;
var pdfPath, numPages;
var cueDict, statusText;

// Configuration - UPDATE THESE PATHS
pdfPath = "/Users/maestro/Documents/Coding/innerSoundScape3/resources/pdfs/processed/output.pdf"; // Change to your PDF path
numPages = 17; // Set to actual number of pages in your PDF

// Cue dictionary - map letters to functions
cueDict = Dictionary.newFrom([
    $a, { "Cue A activated".postln; /* Add your cue A code here */ },
    $b, { "Cue B activated".postln; /* Add your cue B code here */ },
    $c, { "Cue C activated".postln; /* Add your cue C code here */ },
    $d, { "Cue D activated".postln; /* Add your cue D code here */ },
    $e, { "Cue E activated".postln; /* Add your cue E code here */ },
    $f, { "Cue F activated".postln; /* Add your cue F code here */ },
    $g, { "Cue G activated".postln; /* Add your cue G code here */ },
    $h, { "Cue H activated".postln; /* Add your cue H code here */ },
    $i, { "Cue I activated".postln; /* Add your cue I code here */ },
    $j, { "Cue J activated".postln; /* Add your cue J code here */ },
    $k, { "Cue K activated".postln; /* Add your cue K code here */ },
    $l, { "Cue L activated".postln; /* Add your cue L code here */ },
    $m, { "Cue M activated".postln; /* Add your cue M code here */ },
    $n, { "Cue N activated".postln; /* Add your cue N code here */ },
    $o, { "Cue O activated".postln; /* Add your cue O code here */ },
    $p, { "Cue P activated".postln; /* Add your cue P code here */ },
    $q, { "Cue Q activated".postln; /* Add your cue Q code here */ },
    $r, { "Cue R activated".postln; /* Add your cue R code here */ },
    $s, { "Cue S activated".postln; /* Add your cue S code here */ },
    $t, { "Cue T activated".postln; /* Add your cue T code here */ },
    $u, { "Cue U activated".postln; /* Add your cue U code here */ },
    $v, { "Cue V activated".postln; /* Add your cue V code here */ },
    $w, { "Cue W activated".postln; /* Add your cue W code here */ },
    $x, { "Cue X activated".postln; /* Add your cue X code here */ },
    $y, { "Cue Y activated".postln; /* Add your cue Y code here */ },
    $z, { "Cue Z activated".postln; /* Add your cue Z code here */ }
]);

// Function to load and display PDF page
~loadPDFPage = { |pageNum, halfOffset = 0|
    var cmd, imagePath, image;

    // Create temporary image path
    imagePath = "/tmp/score_page_" ++ pageNum ++ "_" ++ halfOffset ++ ".png";

    // Convert PDF page to image using ImageMagick or similar
    // This command converts a PDF page to PNG
    if(halfOffset == 0, {
        // Full page
        cmd = "convert -density 150" + pdfPath.standardizePath + "[" ++ pageNum ++ "]" + imagePath;
    }, {
        // Half page offset - crop the image vertically
        cmd = "convert -density 150" + pdfPath.standardizePath + "[" ++ pageNum ++ "] -crop 100%x50%+0+" ++ (halfOffset * 50) ++ "%" + imagePath;
    });

    // Execute conversion command
    cmd.unixCmd({
        // Load the converted image
        defer {
            if(File.exists(imagePath), {
                image = Image.open(imagePath);
                imageView.setImage(image);
                statusText.string = "Page:" + (pageNum + 1) + "Half:" + halfOffset + "Press SPACE for next half-page, letters for cues";
                ("Loaded page" + (pageNum + 1) + "half" + halfOffset).postln;
            }, {
                statusText.string = "Error loading page" + (pageNum + 1);
                "Error: Could not load PDF page".postln;
            });
        };
    });
};

// Function to advance half page
~advanceHalfPage = {
    if(halfPageOffset == 0, {
        // Currently showing top half, show bottom half
        halfPageOffset = 1;
    }, {
        // Currently showing bottom half, advance to next page
        halfPageOffset = 0;
        currentPage = (currentPage + 1) % numPages;
    });
    ~loadPDFPage.(currentPage, halfPageOffset);
};

// Function to go back half page
~goBackHalfPage = {
    if(halfPageOffset == 1, {
        // Currently showing bottom half, show top half
        halfPageOffset = 0;
    }, {
        // Currently showing top half, go to previous page bottom
        halfPageOffset = 1;
        currentPage = (currentPage - 1 + numPages) % numPages;
    });
    ~loadPDFPage.(currentPage, halfPageOffset);
};

// Create GUI window
window = Window("PDF Score Display", Rect(100, 100, 800, 900))
    .background_(Color.black)
    .onClose_({ "Score display closed".postln; });

// Create image view for PDF display
imageView = ImageView(window, Rect(10, 10, 780, 800))
    .background_(Color.gray(0.2))
    .resize_(5); // Resize with window

// Status text
statusText = StaticText(window, Rect(10, 820, 780, 30))
    .string_("Loading score... Press SPACE for next half-page, letters for cues")
    .stringColor_(Color.white)
    .background_(Color.black);

// Instructions text
StaticText(window, Rect(10, 850, 780, 40))
    .string_("CONTROLS: SPACE = next half-page, SHIFT+SPACE = previous half-page, A-Z = cues, ESC = close")
    .stringColor_(Color.yellow)
    .background_(Color.black)
    .font_(Font("Arial", 10));

// Key event handling
window.view.keyDownAction = { |view, char, modifiers, unicode, keycode|
    case
    { char == $ } { // Space bar
        if(modifiers.isShift, {
            ~goBackHalfPage.();
        }, {
            ~advanceHalfPage.();
        });
    }
    { char == 27.asAscii } { // Escape key
        window.close;
    }
    { char.isAlpha } { // Letter keys
        var lowerChar = char.toLower;
        var cueFunc = cueDict[lowerChar];
        if(cueFunc.notNil, {
            cueFunc.();
            ("Activated cue:" + lowerChar.asString.toUpper).postln;
        }, {
            ("No cue defined for:" + lowerChar.asString.toUpper).postln;
        });
    };
};

// Make window focusable for key events
window.view.canFocus = true;
window.view.focus;

// Show window
window.front;

// Load first page
~loadPDFPage.(0, 0);

// Store window reference for cleanup
~scoreWindow = window;
)