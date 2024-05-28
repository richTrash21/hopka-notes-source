package objects.ui;

import lime.system.Clipboard;

import flixel.addons.ui.FlxInputText;

class InputTextAdvanced extends FlxInputText
{
	public static inline final BACKSPACE_ACTION	= FlxInputText.BACKSPACE_ACTION; // press backspace
	public static inline final DELETE_ACTION	= FlxInputText.DELETE_ACTION; // press delete
	public static inline final ENTER_ACTION	 	= FlxInputText.ENTER_ACTION; // press enter
	public static inline final INPUT_ACTION	 	= FlxInputText.INPUT_ACTION; // manually edit
	public static inline final PASTE_ACTION	 	= "paste"; // text paste
	public static inline final COPY_ACTION		= "copy"; // text copy
	public static inline final CUT_ACTION		= "cut"; // text copy

	@:access(flixel.FlxBasic.activeCount)
	override function update(elapsed:Float)
	{
		//super.update(elapsed);
		// cuz the main method needs to be overriden duhh
		#if FLX_DEBUG
		// this just increments FlxBasic.activeCount, no need to waste a function call on release
		flixel.FlxBasic.activeCount++;
		#end

		last.set(x, y);

		if (path != null && path.active)
			path.update(elapsed);

		if (moves)
			updateMotion(elapsed);

		wasTouching = touching;
		touching = flixel.util.FlxDirectionFlags.NONE;
		updateAnimation(elapsed);

		#if FLX_MOUSE
		// Set focus and caretIndex as a response to mouse press
		if (FlxG.mouse.justPressed)
		{
			var hadFocus:Bool;
			for (camera in getCameras())
			{
				hadFocus = hasFocus;
				if (FlxG.mouse.overlaps(this, camera))
				{
					caretIndex = getCaretIndex();
					hasFocus = true;
					if (!hadFocus && focusGained != null)
						focusGained();
				}
				else
				{
					hasFocus = false;
					if (hadFocus && focusLost != null)
						focusLost();
				}
			}
		}
		#end
	}

	override private function onKeyDown(e:flash.events.KeyboardEvent)
	{
		if (hasFocus)
		{
			var key:Int = e.keyCode;
			var targetKey = #if (macos) e.commandKey #else e.ctrlKey #end;

			if (targetKey)
			{
				switch (key)
				{
					// Crtl/Cmd + C to copy text to the clipboard
					// This copies the entire input, because i'm too lazy to do caret selection, and if i did it i whoud probabbly make it a pr in flixel-ui.
					case 67:
						Clipboard.text = text;
						onChange(COPY_ACTION);
						return; // Stops the function to go further, because it whoud type in a c to the input


					// Crtl/Cmd + V to paste in the clipboard text to the input
					case 86:
						var newText:String = filter(Clipboard.text);

						if (newText.length > 0 && (maxLength == 0 || (text.length + newText.length) < maxLength))
						{
							text = insertSubstring(text, newText, caretIndex);
							caretIndex += newText.length;
							onChange(FlxInputText.INPUT_ACTION);
							onChange(PASTE_ACTION);
						}
						return; // Same as before, but prevents typing out a v


					// Crtl/Cmd + X to cut the text from the input to the clipboard
					// Again, this copies the entire input text because there is no caret selection.
					case 88:
						Clipboard.text = text;
						text = '';
						caretIndex = 0;
	
						onChange(FlxInputText.INPUT_ACTION);
						onChange(CUT_ACTION);
	
						return; // Same as before, but prevents typing out a x
				}
			}
		}
		super.onKeyDown(e);
	}
}