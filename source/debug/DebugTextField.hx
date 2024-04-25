package debug;

import openfl.events.MouseEvent;
import openfl.events.FocusEvent;
import openfl.text.TextFormat;
import openfl.text.TextField;

@:allow(debug.DebugOverlay)
class DebugTextField extends TextField
{
	static var __debugFromat:TextFormat;

	var debug = #if debug true #else false #end;
	var _text:String;

	@:access(openfl.text.TextField.__defaultTextFormat)
	public function new(x = 0.0, y = 0.0):Void
	{
		if (__debugFromat == null)
		{
			__debugFromat = new TextFormat(DebugOverlay.debugFont, 12, 0xFFFFFF, false, false, false, "", "", openfl.text.TextFormatAlign.LEFT, 0, 0, 0, 0);
			__debugFromat.letterSpacing = __debugFromat.blockIndent = 0;
			__debugFromat.kerning = __debugFromat.bullet = false;
		}

		final defaultFormat = TextField.__defaultTextFormat;
		TextField.__defaultTextFormat = __debugFromat;

		super();
		this.x = x;
		this.y = y;

		TextField.__defaultTextFormat = defaultFormat;
		__styleSheet = new openfl.text.StyleSheet();

		selectable = mouseEnabled = false;
		multiline = true;
		autoSize = LEFT;

		// i think it is optimization - Redar
		removeEventListener(FocusEvent.FOCUS_IN, this_onFocusIn);
		removeEventListener(FocusEvent.FOCUS_OUT, this_onFocusOut);
		removeEventListener(MouseEvent.MOUSE_DOWN, this_onMouseDown);
		removeEventListener(MouseEvent.MOUSE_WHEEL, this_onMouseWheel);
		removeEventListener(MouseEvent.DOUBLE_CLICK, this_onDoubleClick);
		removeEventListener(openfl.events.KeyboardEvent.KEY_DOWN, this_onKeyDown);
	}

	function flixelUpdate() {}
}
