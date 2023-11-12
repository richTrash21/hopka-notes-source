package objects.ui;

import lime.system.Clipboard;

import flixel.addons.ui.FlxInputText;

class InputTextAdvanced extends FlxInputText
{
	public static inline var BACKSPACE_ACTION:String = FlxInputText.BACKSPACE_ACTION; // press backspace
	public static inline var DELETE_ACTION:String	 = FlxInputText.DELETE_ACTION; // press delete
	public static inline var ENTER_ACTION:String	 = FlxInputText.ENTER_ACTION; // press enter
	public static inline var INPUT_ACTION:String	 = FlxInputText.INPUT_ACTION; // manually edit
	public static inline var PASTE_ACTION:String	 = "paste"; // text paste
	public static inline var COPY_ACTION:String		 = "copy"; // text copy
	public static inline var CUT_ACTION:String		 = "cut"; // text copy

	override function onKeyDown(e:flash.events.KeyboardEvent)
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