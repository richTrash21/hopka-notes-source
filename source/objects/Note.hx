package objects;

// If you want to make a custom note type, you should search for:
// "function set_noteType"

import flixel.util.FlxDestroyUtil;
import flixel.math.FlxRect;
import flixel.util.FlxSort;

import states.editors.EditorPlayState;
import shaders.RGBPalette;
import objects.StrumNote;

import haxe.extern.EitherType;

typedef NoteSplashData = {
	disabled:Bool,
	texture:String,
	useGlobalShader:Bool, // breaks r/g/b/a but makes it copy default colors for your custom note
	useRGBShader:Bool,
	antialiasing:Bool,
	r:FlxColor,
	g:FlxColor,
	b:FlxColor,
	a:Float
}

class Note extends FlxSprite implements INote
{
	public static final SUSTAIN_SIZE = 44;
	public static final swagWidth = 160 * 0.7;

	public static final colArray:Array<String> = ["purple", "blue", "green", "red"];
	public static final defaultNoteSkin:String = "noteSkins/NOTE_assets";

	public static final globalRgbShaders:Array<RGBPalette> = [];
	@:allow(states.PlayState)
	static var _lastValidChecked:String; // optimization

	public static function initializeGlobalRGBShader(noteData:Int)
	{
		if (globalRgbShaders[noteData] == null)
		{
			final newRGB = new RGBPalette();
			globalRgbShaders[noteData] = newRGB;

			final arr = (PlayState.isPixelStage ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB)[noteData];
			if (noteData > -1 && noteData <= arr.length)
			{
				newRGB.r = arr[0];
				newRGB.g = arr[1];
				newRGB.b = arr[2];
			}
		}
		return globalRgbShaders[noteData];
	}

	inline public static function getNoteSkinPostfix()
	{
		return ClientPrefs.data.noteSkin == ClientPrefs.defaultData.noteSkin ? "" : "-" + ClientPrefs.data.noteSkin.toLowerCase().replace(" ", "_");
	}

	inline public static function sortByTime(Note1:INote, Note2:INote):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Note1.strumTime, Note2.strumTime);
	}

	public var extraData:Map<String, Dynamic> = [];

	public var strumTime:Float = 0;
	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var canBeHit:Bool = false;
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var ignoreNote:Bool = false;
	public var hitByOpponent:Bool = false;
	public var noteWasHit:Bool = false;
	public var prevNote:Note;
	public var nextNote:Note;

	public var spawned:Bool = false;

	public var tail:Array<Note> = []; // for sustains
	public var parent:Note;
	public var blockHit:Bool = false; // only works for player

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var noteType(default, set):String = null;

	public var eventName:String = "";
	public var eventLength:Int = 0;
	public var eventVal1:String = "";
	public var eventVal2:String = "";

	public var rgbShader:RGBShaderReference;
	public var inEditor:Bool = false;

	public var animSuffix:String = "";
	public var gfNote:Bool = false;
	public var earlyHitMult:Float = 1;
	public var lateHitMult:Float = 1;
	public var lowPriority:Bool = false;

	public var noteSplashData:NoteSplashData = {
		disabled: false,
		texture: null,
		antialiasing: !PlayState.isPixelStage,
		useGlobalShader: false,
		useRGBShader: PlayState.SONG == null ? true : !PlayState.SONG?.disableNoteRGB,
		r: -1,
		g: -1,
		b: -1,
		a: ClientPrefs.data.splashAlpha
	};

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var multAlpha:Float = 1;
	public var multSpeed(default, set):Float = 1;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;

	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var rating:String = "unknown";
	public var ratingMod:Float = 0; // 9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick
	public var ratingDisabled:Bool = false;

	public var texture(default, set):String = null;

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var hitCausesMiss:Bool = false;
	public var distance:Float = 2000; // plan on doing scroll directions soon -bb

	public var hitsoundDisabled:Bool = false;
	public var hitsoundChartEditor:Bool = true;
	public var hitsound:String = "hitsound";

	public function resizeByRatio(ratio:Float) // haha funny twitter shit
	{
		if (isSustainNote && animation.curAnim != null && !animation.curAnim.name.endsWith("end"))
		{
			scale.y *= ratio;
			updateHitbox();
		}
	}

	public function defaultRGB()
	{
		final arr = (PlayState.isPixelStage ? ClientPrefs.data.arrowRGBPixel : ClientPrefs.data.arrowRGB)[noteData];
		if (noteData > -1 && noteData <= arr.length)
		{
			rgbShader.r = arr[0];
			rgbShader.g = arr[1];
			rgbShader.b = arr[2];
		}
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote = false, ?inEditor = false, ?createdFrom:Dynamic)
	{
		super();

		antialiasing = ClientPrefs.data.antialiasing;
		if (createdFrom == null)
			createdFrom = PlayState.instance;
		if (prevNote == null)
			prevNote = this;

		this.prevNote = prevNote;
		isSustainNote = sustainNote;
		this.inEditor = inEditor;
		this.moves = false;

		x += (ClientPrefs.data.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;
		this.strumTime = strumTime;
		if (!inEditor)
			this.strumTime += ClientPrefs.data.noteOffset;

		this.noteData = noteData;

		if (noteData > -1)
		{
			texture = "";
			rgbShader = new RGBShaderReference(this, initializeGlobalRGBShader(noteData));
			if (PlayState.SONG != null && PlayState.SONG.disableNoteRGB)
				rgbShader.enabled = false;

			x += swagWidth * (noteData);
			if (!isSustainNote && noteData < colArray.length) // Doing this "if" check to fix the warnings on Senpai songs
				animation.play(colArray[noteData % colArray.length] + "Scroll");
		}
		if (prevNote != null)
			prevNote.nextNote = this;

		if (isSustainNote && prevNote != null)
		{
			multAlpha = alpha = ClientPrefs.data.susAlpha;
			hitsoundDisabled = true;
			if (ClientPrefs.data.downScroll)
				flipY = true;

			offsetX += width / 2;
			copyAngle = false;

			animation.play(colArray[noteData % colArray.length] + "holdend");

			updateHitbox();

			offsetX -= width / 2;
			if (PlayState.isPixelStage)
				offsetX += 30;

			if (prevNote.isSustainNote)
			{
				prevNote.animation.play(colArray[prevNote.noteData % colArray.length] + "hold");

				prevNote.scale.y *= Conductor.stepCrochet / 100 * 1.05;
				if (createdFrom != null && createdFrom.songSpeed != null)
					prevNote.scale.y *= createdFrom.songSpeed;

				if (PlayState.isPixelStage)
				{
					prevNote.scale.y *= 1.19;
					prevNote.scale.y *= (6 / height); //Auto adjust note size
				}
				prevNote.updateHitbox();
			}

			if (PlayState.isPixelStage)
			{
				scale.y *= PlayState.daPixelZoom;
				updateHitbox();
			}
			earlyHitMult = 0;
		}
		else if (!isSustainNote)
		{
			centerOffsets();
			centerOrigin();
		}
		x += offsetX;

		if (isSustainNote)
			clipRect = FlxRect.get(0, 0, frameWidth, frameHeight);
	}

	var _lastNoteOffX:Float = 0;
	public var originalHeight:Float = 6;
	public var correctionOffset:Float = 0; //dont mess with this
	public function reloadNote(?texture:String, ?postfix:String)
	{
		if (texture == null)
			texture = "";
		if (postfix == null)
			postfix = "";

		var skin = texture + postfix;
		if (texture.length < 1)
		{
			skin = PlayState.SONG?.arrowSkin;
			if (skin == null || skin.length < 1)
				skin = defaultNoteSkin + postfix;
		}

		var skinPostfix = getNoteSkinPostfix();
		final animName = animation.curAnim?.name;
		final skinPixel = skin;
		final lastScaleY = scale.y;
		final customSkin = skin + skinPostfix;
		final path = PlayState.isPixelStage ? "pixelUI/" : "";

		if (customSkin == _lastValidChecked || Paths.fileExists('images/$path$customSkin.png', IMAGE))
		{
			skin = customSkin;
			_lastValidChecked = customSkin;
		}
		else
			skinPostfix = "";

		if (PlayState.isPixelStage)
		{
			var graphic:flixel.graphics.FlxGraphic;
			if (isSustainNote)
			{
				graphic = Paths.image('pixelUI/$skinPixel' + 'ENDS$skinPostfix');
				loadGraphic(graphic, true, Math.floor(graphic.width * 0.25), Math.floor(graphic.height * 0.5));
				originalHeight = graphic.height * 0.5;
			}
			else
			{
				graphic = Paths.image('pixelUI/$skinPixel$skinPostfix');
				loadGraphic(graphic, true, Math.floor(graphic.width * 0.25), Math.floor(graphic.height * 0.2));
			}
			setGraphicSize(width * PlayState.daPixelZoom);
			loadPixelNoteAnims();
			antialiasing = false;

			if (isSustainNote)
			{
				offsetX += _lastNoteOffX;
				_lastNoteOffX = (width - 7) * (PlayState.daPixelZoom * 0.5);
				offsetX -= _lastNoteOffX;
			}
		}
		else
		{
			frames = Paths.getSparrowAtlas(skin);
			loadNoteAnims();
			if (!isSustainNote)
			{
				centerOffsets();
				centerOrigin();
			}
		}
		if (isSustainNote)
			scale.y = lastScaleY;
		updateHitbox();

		if (animName != null)
			animation.play(animName, true);
	}

	function loadNoteAnims()
	{
		final color = colArray[noteData];
		if (isSustainNote)
		{
			if (noteData == 0 && frames.framesHash.exists("pruple end hold0000")) // this fixes some retarded typo from the original note .FLA
				animation.addByPrefix("purpleholdend", "pruple end hold", 24, true);
			else
				animation.addByPrefix(color + "holdend", '$color hold end', 24, true);
			animation.addByPrefix(color + "hold", '$color hold piece', 24, true);
		}
		else
			animation.addByPrefix(color + "Scroll", color + "0");

		setGraphicSize(width * 0.7);
		updateHitbox();
	}

	function loadPixelNoteAnims()
	{
		final color = colArray[noteData];
		if (isSustainNote)
		{
			animation.add(color + "holdend", [noteData + 4], 24, true);
			animation.add(color + "hold", [noteData], 24, true);
		}
		else
			animation.add(color + "Scroll", [noteData + 4], 24, true);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			canBeHit = (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult) &&
						strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult));
			tooLate = (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit);
		}
		else
		{
			canBeHit = false;
			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				wasGoodHit = ((isSustainNote && prevNote.wasGoodHit) || strumTime <= Conductor.songPosition);
		}

		if (tooLate && !inEditor)
			if (alpha > 0.3)
				alpha = 0.3;
	}

	override public function destroy()
	{
		clipRect = FlxDestroyUtil.put(clipRect);
		extraData = CoolUtil.clear(extraData);
		noteSplashData = null;
		rgbShader = null;
		prevNote = null;
		nextNote = null;
		parent = null;
		tail = null;

		super.destroy();
		// _lastValidChecked = "";
	}

	public function followStrumNote(myStrum:StrumNote, fakeCrochet:Float, songSpeed:Float = 1)
	{
		distance = (0.45 * (Conductor.songPosition - strumTime) * songSpeed * multSpeed);
		if (!myStrum.downScroll)
			distance = -distance;

		final angleDir = myStrum.direction * Math.PI / 180;
		if (copyAngle)
			angle = myStrum.direction - 90 + myStrum.angle + offsetAngle;
		if (copyAlpha)
			alpha = myStrum.alpha * multAlpha;

		if (copyX)
			x = myStrum.x + offsetX + Math.cos(angleDir) * distance;
		if (copyY)
		{
			y = myStrum.y + offsetY + correctionOffset + Math.sin(angleDir) * distance;
			if (myStrum.downScroll && isSustainNote)
			{
				if (PlayState.isPixelStage)
					y -= PlayState.daPixelZoom * 9.5;
				y -= (frameHeight * scale.y) - (swagWidth * 0.5);
			}
		}
	}

	public function clipToStrumNote(myStrum:StrumNote)
	{
		if (isSustainNote && (mustPress || !ignoreNote) && (!mustPress || (wasGoodHit || (prevNote.wasGoodHit && !canBeHit))))
		{
			final center = myStrum.y + offsetY + swagWidth * 0.5;
			if (myStrum.downScroll)
			{
				if (y - offset.y * scale.y + height >= center)
				{
					clipRect.width = frameWidth;
					clipRect.height = (center - y) / scale.y;
					clipRect.y = frameHeight - clipRect.height;
				}
			}
			else if (y + offset.y * scale.y <= center)
			{
				clipRect.y = (center - y) / scale.y;
				clipRect.width = width / scale.x;
				clipRect.height = (height / scale.y) - clipRect.y;
			}
			clipRect = clipRect;
		}
	}

	@:noCompletion override function set_clipRect(rect:FlxRect):FlxRect
	{
		clipRect = rect;
		if (frames != null)
			frame = frames.frames[animation.frameIndex];

		return rect;
	}

	@:noCompletion inline function set_multSpeed(value:Float):Float
	{
		resizeByRatio(value / multSpeed);
		return multSpeed = value;
	}

	@:noCompletion inline function set_texture(value:String):String
	{
		if (texture != value)
			reloadNote(value);
		return texture = value;
	}

	@:noCompletion private function set_noteType(value:String):String
	{
		// noteSplashData.texture = PlayState.SONG?.splashSkin ?? "noteSplashes/noteSplashes" + NoteSplash.getSplashSkinPostfix();
		noteSplashData.texture = null;
		defaultRGB();
		if (noteData != -1 && noteType != value)
		{
			switch(value)
			{
				case "Hurt Note":
					ignoreNote = mustPress;
					// reloadNote("HURTNOTE_assets");
					// this used to change the note texture to HURTNOTE_assets.png,
					// but i've changed it to something more optimized with the implementation of RGBPalette:

					// note colors
					rgbShader.r = 0xFF101010;
					rgbShader.g = 0xFFFF0000;
					rgbShader.b = 0xFF990022;

					// splash data and colors
					noteSplashData.r = 0xFFFF0000;
					noteSplashData.g = 0xFF101010;
					noteSplashData.texture = "noteSplashes/noteSplashes-electric";

					// gameplay data
					lowPriority = true;
					missHealth = isSustainNote ? 0.25 : 0.1;
					hitCausesMiss = true;
					hitsound = "cancelMenu";
					hitsoundChartEditor = false;

				case "Alt Animation":
					animSuffix = "-alt";

				case "No Animation":
					noAnimation = true;
					noMissAnimation = true;

				case "GF Sing":
					gfNote = true;
			}
			if (value != null && value.length > 1)
				backend.NoteTypesConfig.applyNoteTypeData(this, value);
			if (hitsound != "hitsound" && ClientPrefs.data.hitsoundVolume > 0)
				Paths.sound(hitsound); // precache new sound for being idiot-proof
			noteType = value;
		}
		return value;
	}
}

@:structInit class EventNote implements INote
{
	public var strumTime:Float;
	public var event:String;
	public var value1:String;
	public var value2:String;
}

interface INote
{
	var strumTime:Float;
}