package backend;

/**
	An exact copy of MusicBeatState, but extending FlxUIState (whitch was originaly a MusicBeatState thing lmao)
 **/
class MusicBeatUIState extends flixel.addons.ui.FlxUIState implements IMusicBeatState
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

	public function new() { super(); }

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

	override public function startOutro(onOutroComplete:()->Void)
	{
		if (StateTransition.skipNextTransIn)
		{
			StateTransition.skipNextTransIn = false;
			return super.startOutro(onOutroComplete);
		}
		// Custom made Trans in
		Main.transition.start(onOutroComplete, StateTransition.transTime, false);
	}

	public function stepHit():Void {}
	public function beatHit():Void {}
	public function sectionHit():Void {}

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}
