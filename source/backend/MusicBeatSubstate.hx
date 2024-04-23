package backend;

class MusicBeatSubstate extends flixel.FlxSubState implements IMusicBeatState
{
	public var curSection = 0;
	public var stepsToDo = 0;

	public var curStep = 0;
	public var curBeat = 0;
	public var curDecStep = 0.0;
	public var curDecBeat = 0.0;

	public var lastBeat = -1;
	public var lastStep = -1;

	public var controls(get, never):Controls;

	override function update(elapsed:Float)
	{
		MusicBeatStateHelper.update(this);
		super.update(elapsed);
	}

	override function tryUpdate(elapsed:Float)
	{
		if (CoolUtil.__update__state__check(this))
			update(elapsed);

		if (_requestSubStateReset)
		{
			_requestSubStateReset = false;
			resetSubState();
		}
		if (subState != null)
			subState.tryUpdate(elapsed);
	}

	public function stepHit():Void {}
	public function beatHit():Void {}
	public function sectionHit():Void {}

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}
