package backend;

class BaseState extends flixel.FlxState
{
	public var controls(get, never):Controls;

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

	// transition is not substate anymore so had to change this a bit
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

	@:noCompletion inline function get_controls():Controls
	{
		return Controls.instance;
	}
}