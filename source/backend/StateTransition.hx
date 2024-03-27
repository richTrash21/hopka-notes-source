package backend;

import flixel.addons.transition.FlxTransitionableState;
import flixel.util.typeLimit.NextState;

class StateTransition extends openfl.display.Bitmap
{
	// TRANS RIGHTS!!!!
	public static final transTime = .45; // uniform transition time
	static final colors = [FlxColor.BLACK, FlxColor.BLACK, 0];

	public var active(default, null):Bool;

	@:noCompletion var _time:Float;
	@:noCompletion var _duration:Float;
	@:noCompletion var _startPos:Float;
	@:noCompletion var _targetPos:Float;
	@:noCompletion var _nextState:NextState;
	@:noCompletion var _resetState:Bool;

	// singleton yaaaaaaayy
	@:allow(Main)
	function new()
	{
		super(flixel.util.FlxGradient.createGradientBitmapData(1, FlxG.height * 2, colors), null, true);
		visible = false;

		FlxG.signals.preUpdate.add(update);
		FlxG.signals.gameResized.add(onResize);
		FlxG.signals.postStateSwitch.add(onStateSwitched);
		FlxG.cameras.cameraAdded.add(onCameraAdded);
	}

	public function start(?nextState:NextState, duration:Float, isTransIn:Bool)
	{
		_time = 0.0;
		active = true;
		visible = true;
		_nextState = nextState;
		_resetState = (nextState == null && !isTransIn);
		_duration = Math.max(duration, 0.00001);

		prepare(isTransIn);

		// to avoid visual bugs
		y = _startPos;
	}

	@:noCompletion function finish(?_)
	{
		active = false;
		if (_resetState)
			FlxG.resetState();
		else
		{
			if (_nextState == null)
				visible = false;
			else
				FlxG.switchState(_nextState);
		}
	}

	@:noCompletion function prepare(isTransIn:Bool)
	{
		scaleX = FlxG.scaleMode.gameSize.x;
		if (isTransIn)
		{
			scaleY = -FlxG.scaleMode.scale.y;
			_startPos = FlxG.scaleMode.gameSize.y;
			_targetPos = FlxG.scaleMode.gameSize.y * 3.0;
		}
		else
		{
			scaleY = FlxG.scaleMode.scale.y;
			_startPos = -FlxG.scaleMode.gameSize.y * 2.0;
			_targetPos = 0.0;
		}
	}

	@:noCompletion function update()
	{
		if (!active)
			return;

		if (_time < _duration) // move transition graphic
			y = FlxMath.lerp(_startPos, _targetPos, Math.min(_time / _duration, 1.0));
		else // finish transition
			finish();

		_time += FlxG.elapsed;
	}

	@:noCompletion function onResize(_, _)
	{
		prepare(_startPos < _targetPos);
	}

	@:noCompletion function onStateSwitched()
	{
		if (FlxTransitionableState.skipNextTransOut)
		{
			visible = false;
			FlxTransitionableState.skipNextTransOut = false;
		}
		else
			start(transTime * 1.1, true);
	}

	@:noCompletion function onCameraAdded(camera:FlxCamera)
	{
		// sets transition above added camera
		FlxG.game.swapChildren(this, camera.flashSprite);
	}
}