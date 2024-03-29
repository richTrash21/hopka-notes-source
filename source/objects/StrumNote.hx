package objects;

import shaders.RGBPalette.RGBShaderReference;

class StrumNote extends FlxSprite
{
	public var rgbShader:RGBShaderReference;
	public var resetAnim:Float = 0;
	public var direction:Float = 90; // plan on doing scroll directions soon -bb
	public var downScroll:Bool = false; // plan on doing scroll directions soon -bb
	public var sustainReduce:Bool = true;
	public var useRGBShader:Bool = true;
	public var texture(default, set):String;

	var noteData:Int = 0;
	var player:Int;

	public function new(x:Float, y:Float, leData:Int, player:Int)
	{
		rgbShader = new RGBShaderReference(this, Note.initializeGlobalRGBShader(leData));
		rgbShader.enabled = false;
		if (PlayState.SONG?.disableNoteRGB)
			useRGBShader = false;
		
		final arr = (PlayState.isPixelStage ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB)[leData % 4];
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

		var skin = (PlayState.SONG?.arrowSkin != null && PlayState.SONG.arrowSkin.length > 1)
			? PlayState.SONG.arrowSkin
			: Note.defaultNoteSkin;

		final customSkin:String = skin + Note.getNoteSkinPostfix();
		if (Paths.fileExists('images/$customSkin.png', IMAGE))
			skin = customSkin;

		texture = skin; // Load texture and anims
		// scrollFactor.set();
	}

	public function reloadNote()
	{
		final lastAnim = animation.curAnim?.name;
		final daNoteData = FlxMath.absInt(noteData) % 4;
		if (PlayState.isPixelStage)
		{
			final graphic = Paths.image("pixelUI/" + (Paths.fileExists('images/pixelUI/$texture.png', IMAGE) ? texture : Note.defaultNoteSkin));
			loadGraphic(graphic, true, Math.floor(graphic.width * 0.25), Math.floor(graphic.height * 0.2));

			antialiasing = false;
			setGraphicSize(width * PlayState.daPixelZoom);

			animation.add("green", [6]);
			animation.add("red", [7]);
			animation.add("blue", [5]);
			animation.add("purple", [4]);

			animation.add("static", [daNoteData]);
			animation.add("pressed", [4 + daNoteData, 8 + daNoteData], 12, false);
			animation.add("confirm", [12 + daNoteData, 16 + daNoteData], 24, false);
		}
		else
		{
			frames = Paths.getSparrowAtlas(Paths.fileExists('images/$texture.png', IMAGE) ? texture : Note.defaultNoteSkin);
			animation.addByPrefix("green", "arrowUP");
			animation.addByPrefix("blue", "arrowDOWN");
			animation.addByPrefix("purple", "arrowLEFT");
			animation.addByPrefix("red", "arrowRIGHT");

			antialiasing = ClientPrefs.data.antialiasing;
			setGraphicSize(width * 0.7);

			final animSuffix = switch (daNoteData)
			{
				case 1:  "down";
				case 2:  "up";
				case 3:  "right";
				default: "left"; // case 0:
			}
			animation.addByPrefix("static", "arrow" + animSuffix.toUpperCase());
			animation.addByPrefix("pressed", '$animSuffix press', 24, false);
			animation.addByPrefix("confirm", '$animSuffix confirm', 24, false);
		}
		updateHitbox();
		if (lastAnim != null)
			playAnim(lastAnim, true);
	}

	public function postAddedToGroup()
	{
		playAnim("static");
		x += Note.swagWidth * noteData + 50 + ((FlxG.width * 0.5) * player);
		ID = noteData;
	}

	override function update(elapsed:Float)
	{
		if (resetAnim > 0)
			if ((resetAnim -= elapsed) <= 0)
				playAnim("static");

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
			rgbShader.enabled = (animation.curAnim != null && animation.curAnim.name != "static");
	}

	override function destroy()
	{
		rgbShader = null;
		super.destroy();
	}

	@:noCompletion inline function set_texture(value:String):String
	{
		if (texture != value)
		{
			texture = value;
			reloadNote();
		}
		return value;
	}
}
