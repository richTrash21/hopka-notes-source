package backend;

class StateTransition extends openfl.display.Bitmap
{
	/** TRANS RIGHTS!!!! Uniform transition time. **/
	public static final transTime = .45;
	static final colors = [FlxColor.BLACK, FlxColor.BLACK, FlxColor.TRANSPARENT];

	public static var skipNextTransIn = false;
	public static var skipNextTransOut = false;

	public var active(default, null):Bool;
	public var ease:EaseFunction = FlxEase.linear;

	@:noCompletion var _time:Float;
	@:noCompletion var _duration:Float;
	@:noCompletion var _startPos:Float;
	@:noCompletion var _targetPos:Float;
	@:noCompletion var _onComplete:()->Void;

	// singleton yaaaaaaayy
	@:allow(Main) function new()
	{
		super(flixel.util.FlxGradient.createGradientBitmapData(1, FlxG.height * 2, colors));
		__bitmapData.disposeImage();
		visible = false;

		FlxG.signals.preUpdate.add(update);
		FlxG.signals.gameResized.add(onResize);
		FlxG.signals.postStateSwitch.add(onStateSwitched);
		FlxG.cameras.cameraAdded.add(onCameraAdded);
	}

	public function start(?onComplete:()->Void, duration:Float, isTransIn:Bool)
	{
		_time = 0.0;
		_onComplete = onComplete;
		_duration = Math.max(duration, FlxPoint.EPSILON);

		active = true;
		visible = true;
		smoothing = ClientPrefs.data.antialiasing;
		prepare(isTransIn);
		y = _startPos; // to avoid visual bugs
	}

	@:noCompletion function update()
	{
		if (active)
		{
			_time += FlxG.elapsed;
			if (_time < _duration) // move transition graphic
			{
				if (ease == null)
					ease = FlxEase.linear;

				y = FlxMath.lerp(_startPos, _targetPos, ease(_time / _duration));
			}
			else // finish transition
			{
				y = _targetPos;
				finish();
			}
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

	@:noCompletion function finish()
	{
		active = false;
		if (_onComplete == null)
			visible = false;
		else
		{
			_onComplete();
			_onComplete = null;
		}
	}

	@:noCompletion function onResize(_, _)
	{
		if (active)
			prepare(_startPos > 0);
	}

	@:noCompletion function onStateSwitched()
	{
		if (skipNextTransOut)
		{
			visible = false;
			skipNextTransOut = false;
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