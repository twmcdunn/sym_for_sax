/*
To start the patch, click anywhere in the code below and press command + return (control + enter on windows).
This is a comment, not code... don't click here. Seriously, it won't do anything.

A graphical user (gui) interface will appear. To activate a live electronics cue, simply press the letter on the keyboard corresponding to the cue in the score. The letters move from left to right and top to bottom across the keyboard. When you get to the last letter ‘m’, you will see the cue set number advance, and the letters start over. You can also click the cue set numbers in the gui to change sets. This can be useful in rehearsal, making it possible to jump directly to any cue desired. Arrow keys turn the page.

*/
(
{
	var filePath = Document.current.dir ++ "/dependencies/combined_patch_v2.scd";
	filePath.load;
}.value;
)