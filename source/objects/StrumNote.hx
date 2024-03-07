package objects;

import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends FlxSprite
{
	public static final defaultNoteSkin:String = Note.defaultNoteSkin;

	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	private var noteData:Int = 0;
	public var direction:Float = 90;//plan on doing scroll directions soon -bb
	public var downScroll:Bool = false;//plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;
	private var player:Int;

	// better pixel note handeling
	public var isPixelNote:Bool = false;
	public var pixelScale:Float = 6;
	
	public var texture(default, set):String = null;
	private function set_texture(value:String):String
	{
		if (texture == value) return value;
		texture = value;
		reloadNote();
		return value;
	}

	public var useRGBShader:Bool = true;
	public function new(x:Float, y:Float, leData:Int, player:Int)
	{
		isPixelNote = PlayState.isPixelStage;
		pixelScale = PlayState.daPixelZoom;
		final _song = PlayState.SONG;

		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if (_song != null && _song.disableNoteRGB) useRGBShader = false;
		
		final arr:Array<FlxColor> = isPixelNote ? ClientPrefs.data.arrowRGBPixel[leData] : ClientPrefs.data.arrowRGB[leData];
		if (leData <= arr.length)
		{
			@:bypassAccessor
			{
				rgbShader.r = arr[0];
				rgbShader.g = arr[1];
				rgbShader.b = arr[2];
			}
		}

		noteData = leData;
		this.player = player;
		this.noteData = leData;
		super(x, y);

		var skin:String = (#if (haxe > "4.2.5") _song?.arrowSkin != null && _song?.arrowSkin.length
			#else _song != null && _song.arrowSkin != null && _song.arrowSkin.length #end > 1)
			? _song.arrowSkin
			: defaultNoteSkin;

		final customSkin:String = skin + Note.getNoteSkinPostfix();
		if (Paths.fileExists('images/$customSkin.png', IMAGE)) skin = customSkin;

		texture = skin; //Load texture and anims
		//scrollFactor.set();
	}

	public function reloadNote()
	{
		final lastAnim:String = #if (haxe > "4.2.5") animation.curAnim?.name #else animation.curAnim != null ? animation.curAnim.name : null #end;

		if (isPixelNote)
		{
			final graphic = Paths.image('pixelUI/' + (Paths.fileExists('images/pixelUI/$texture.png', IMAGE) ? texture : defaultNoteSkin));
			loadGraphic(graphic, true, Math.floor(graphic.width / 4), Math.floor(graphic.height / 5));

			antialiasing = false;
			setGraphicSize(width * pixelScale);

			animation.add('green', [6]);
			animation.add('red', [7]);
			animation.add('blue', [5]);
			animation.add('purple', [4]);
			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.add('static', [0]);
					animation.add('pressed', [4, 8], 12, false);
					animation.add('confirm', [12, 16], 24, false);
				case 1:
					animation.add('static', [1]);
					animation.add('pressed', [5, 9], 12, false);
					animation.add('confirm', [13, 17], 24, false);
				case 2:
					animation.add('static', [2]);
					animation.add('pressed', [6, 10], 12, false);
					animation.add('confirm', [14, 18], 12, false);
				case 3:
					animation.add('static', [3]);
					animation.add('pressed', [7, 11], 12, false);
					animation.add('confirm', [15, 19], 24, false);
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(Paths.fileExists('images/$texture.png', IMAGE) ? texture : defaultNoteSkin);
			animation.addByPrefix('green', 'arrowUP');
			animation.addByPrefix('blue', 'arrowDOWN');
			animation.addByPrefix('purple', 'arrowLEFT');
			animation.addByPrefix('red', 'arrowRIGHT');

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(width * 0.7);

			switch (Math.abs(noteData) % 4)
			{
				case 0:
					animation.addByPrefix('static', 'arrowLEFT');
					animation.addByPrefix('pressed', 'left press', 24, false);
					animation.addByPrefix('confirm', 'left confirm', 24, false);
				case 1:
					animation.addByPrefix('static', 'arrowDOWN');
					animation.addByPrefix('pressed', 'down press', 24, false);
					animation.addByPrefix('confirm', 'down confirm', 24, false);
				case 2:
					animation.addByPrefix('static', 'arrowUP');
					animation.addByPrefix('pressed', 'up press', 24, false);
					animation.addByPrefix('confirm', 'up confirm', 24, false);
				case 3:
					animation.addByPrefix('static', 'arrowRIGHT');
					animation.addByPrefix('pressed', 'right press', 24, false);
					animation.addByPrefix('confirm', 'right confirm', 24, false);
			}
		}
		updateHitbox();
		if (lastAnim != null) playAnim(lastAnim, true);
	}

	public function postAddedToGroup()
	{
		playAnim('static');
		x += Note.swagWidth * noteData + 50 + ((FlxG.width / 2) * player);
		ID = noteData;
	}

	override function update(elapsed:Float)
	{
		if (resetAnim > 0)
		{
			resetAnim -= elapsed;
			if (resetAnim <= 0)
			{
				playAnim('static');
				resetAnim = 0;
			}
		}
		super.update(elapsed);
	}

	public function playAnim(anim:String, ?force:Bool = false)
	{
		animation.play(anim, force);
		if (animation.curAnim != null)
		{
			centerOffsets();
			centerOrigin();
		}
		if (useRGBShader)
			rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != 'static');
	}

	override function destroy()
	{
		rgbShader = null;
		super.destroy();
	}
}
