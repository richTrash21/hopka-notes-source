package states;

#if haxeui_flixel
import haxe.ui.Toolkit;

class HaxeUITestState extends backend.BaseState
{
	override public function create()
	{
		Toolkit.init();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);
		if (FlxG.keys.justPressed.ESCAPE)
			MusicBeatState.switchState(MainMenuState.new);
	}
}
#end