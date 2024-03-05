package objects.ui;

import flixel.addons.ui.interfaces.IFlxUIWidget;
import flixel.addons.ui.interfaces.IHasParams;
import flixel.addons.ui.interfaces.IResizable;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUI;

/**
 * @author Lars Doucet
 * edited by richTrash21
 */
class UIInputTextAdvanced extends InputTextAdvanced implements IResizable implements IFlxUIWidget implements IHasParams
{
	public var name:String;
	public var broadcastToFlxUI = true;

	public static inline final CHANGE_EVENT = FlxUIInputText.CHANGE_EVENT; // change in any way
	public static inline final ENTER_EVENT  = FlxUIInputText.ENTER_EVENT; // hit enter in this text field
	public static inline final DELETE_EVENT = FlxUIInputText.DELETE_EVENT; // delete text in this text field
	public static inline final INPUT_EVENT  = FlxUIInputText.INPUT_EVENT; // input text in this text field
	public static inline final COPY_EVENT   = "copy_input_text"; // copy text in this text field
	public static inline final PASTE_EVENT  = "paste_input_text"; // paste text in this text field
	public static inline final CUT_EVENT    = "cut_input_text"; // cut text in this text field

	public function resize(w:Float, h:Float):Void
	{
		width = w;
		height = h;
		calcFrame();
	}

	private override function onChange(action:String):Void
	{
		super.onChange(action);
		if (broadcastToFlxUI)
		{
			switch (action)
			{
				case InputTextAdvanced.ENTER_ACTION: // press enter
					FlxUI.event(ENTER_EVENT, this, text, params);

				case InputTextAdvanced.DELETE_ACTION, InputTextAdvanced.BACKSPACE_ACTION: // deleted some text
					FlxUI.event(DELETE_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);

				case InputTextAdvanced.INPUT_ACTION: // text was input
					FlxUI.event(INPUT_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);

				case InputTextAdvanced.COPY_ACTION: // text was copied
					FlxUI.event(COPY_EVENT, this, text, params);

				case InputTextAdvanced.PASTE_ACTION: // text was pasted
					FlxUI.event(PASTE_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);

				case InputTextAdvanced.CUT_ACTION: // text was cut
					FlxUI.event(CUT_EVENT, this, text, params);
					FlxUI.event(CHANGE_EVENT, this, text, params);
			}
		}
	}
}
