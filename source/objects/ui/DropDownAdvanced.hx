package objects.ui;

import flixel.addons.ui.*;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.math.FlxPoint;
import flixel.math.FlxMath;
import flixel.FlxG;

/**
	THIS IS AN EDIT OF FlxUIDropDownMenu I'VE MADE BECAUSE I'M TIRED OF IT NOT SUPPORTING SCROLLING UP/DOWN
	BAH!

	The differences are the following:
	* Support to scrolling up/down with mouse wheel or arrow keys
	* The default drop direction is "Down" instead of "Automatic"

	Made an extencion of FlxUIDropDownMenu cause why does it need to override original class????
	Also because this: https://github.com/ShadowMario/FNF-PsychEngine/pull/13586
**/
class DropDownAdvanced extends FlxUIDropDownMenu
{
	private var currentScroll(default, set):Int = 0; //Handles the scrolling
	public var canScroll:Bool = true;

	function set_currentScroll(scroll:Int):Int
	{
		currentScroll = Std.int(FlxMath.bound(scroll, 0, list.length - 1));
		updateButtonPositions();
		return currentScroll;
	}

	public function new(X:Float = 0, Y:Float = 0, DataList:Array<StrNameLabel>, ?Callback:String->Void, ?Header:FlxUIDropDownHeader,
		?DropPanel:FlxUI9SliceSprite, ?ButtonList:Array<FlxUIButton>, ?UIControlCallback:Bool->FlxUIDropDownMenu->Void)
	{
		super(X, Y, DataList, Callback, Header, DropPanel, ButtonList, UIControlCallback);
		dropDirection = Down;
	}

	override private function updateButtonPositions()
	{
		var buttonHeight:Float = header.background.height;

		super.updateButtonPositions();

		var offset:Float = dropPanel.y;
		for (button in list)
		{
			if (button != null)
			{
				if (list.indexOf(button) < currentScroll)
				{
					// Hides buttons that goes before the current scroll
					button.y = -99999;
				}
				else
				{
					button.y = offset;
					offset += buttonHeight;
				}
			}
		}
	}

	public override function update(elapsed:Float)
	{
		group.update(elapsed);

		if (moves)
			updateMotion(elapsed);

		#if FLX_MOUSE
		if (dropPanel.visible)
		{
			if (canScroll && list.length > 1)
			{
				var wheel:Int = FlxG.mouse.wheel;
				if (wheel > 0 || FlxG.keys.justPressed.UP)
					--currentScroll; // Go up
				else if (wheel < 0 || FlxG.keys.justPressed.DOWN)
					currentScroll++; // Go down
			}

			if (FlxG.mouse.justPressed && !mouseOverlapping())
				showList(false);
		}
		#end
	}

	function mouseOverlapping()
	{
		var mousePoint:FlxPoint = FlxG.mouse.getScreenPosition(camera);
		var objPoint:FlxPoint = this.getScreenPosition(null, camera);
		var ret:Bool = FlxMath.pointInCoordinates(mousePoint.x, mousePoint.y, objPoint.x, objPoint.y, this.width, this.height);
		mousePoint.put();
		objPoint.put();
		return ret;
	}

	override private function showList(b:Bool)
	{
		super.showList(b);
		currentScroll = 0;
	}
}