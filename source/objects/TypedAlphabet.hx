package objects;

class TypedAlphabet extends Alphabet
{
	public var onFinish:()->Void;
	public var finishedText = false;
	public var sound(default, set):String = "dialogue";
	public var volume(get, set):Float;
	public var delay = .05;

	@:noCompletion var _sound:FlxSound;
	// @:noCompletion var _textLen = 0;
	@:noCompletion var _curLetter = -1;
	@:noCompletion var _timeToUpdate = 0.;
	
	@:noCompletion static final IGNORE_REGEX = ~/\s/;

	public function new(x:Float, y:Float, text = "", delay = .05, bold = false)
	{
		super(x, y, text, bold);
		this.delay = delay;
		_sound = FlxG.sound.load(Paths.sound(sound));
	}

	override public function update(elapsed:Float)
	{
		if (!finishedText)
		{
			var playedSound = false;
			while ((_timeToUpdate += elapsed) >= delay)
			{
				showCharacterUpTo(_curLetter + 1);
				if (!playedSound && (delay > .025 || FlxMath.isEven(_curLetter)) && !IGNORE_REGEX.match(members[_curLetter].character))
				{
					// _sound.pitch = FlxG.random.float(.9, 1.1); // omori
					_sound.play(true);
				}

				playedSound = true;
				if (++_curLetter >= lettersLength)
				{
					__finish();
					break;
				}
				_timeToUpdate = 0;
			}
		}

		super.update(elapsed);
	}

	public function showCharacterUpTo(upTo:Int)
	{
		if (_curLetter < 0)
			_curLetter = 0;
		forEachAlive((letter) -> if (FlxMath.inBounds(letter.ID, _curLetter, upTo)) letter.visible = true);
	}

	public function resetDialogue()
	{
		_curLetter = -1;
		_timeToUpdate = 0;
		finishedText = false;
		forEachAlive((letter) -> letter.visible = false);
	}

	public function finishText()
	{
		if (finishedText)
			return;

		showCharacterUpTo(lettersLength - 1);
		_sound.play(true);
		__finish();
	}

	@:noCompletion inline function __finish()
	{
		finishedText = true;
		if (onFinish != null)
			onFinish();
		_timeToUpdate = 0;
	}

	@:noCompletion override function set_text(newText:String):String
	{
		newText = super.set_text(newText);
		// _textLen = FlxMath.maxInt(0, countLiving());
		resetDialogue();
		return newText;
	}

	@:noCompletion function set_sound(value:String):String
	{
		_sound.loadEmbedded(Paths.sound(value));
		return sound = value;
	}

	@:noCompletion inline function set_volume(value:Float):Float  return _sound.volume = value;
	@:noCompletion inline function get_volume():Float			  return _sound.volume;
}