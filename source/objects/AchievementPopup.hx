package objects;

#if ACHIEVEMENTS_ALLOWED
import openfl.events.Event;
import openfl.geom.Matrix;
// import openfl.Lib;

import backend.Achievements;

class AchievementPopup extends openfl.display.Sprite
{
	// public var onFinish:()->Void;
	var alphaTween:FlxTween;
	var lastScale:Float = 1;

	public function new(achieve:String/*, onFinish:()->Void*/)
	{
		super();

		// bg
		graphics.beginFill(FlxColor.BLACK);
		graphics.drawRoundRect(0, 0, 420, 130, 16, 16);

		// achievement icon
		var graphic:flixel.graphics.FlxGraphic;
		var hasAntialias:Bool = ClientPrefs.data.antialiasing;
		final image:String = 'achievements/$achieve';
		
		final achievement = Achievements.get(achieve);

		#if MODS_ALLOWED
		var lastMod = Mods.currentModDirectory;
		if (achievement != null)
			Mods.currentModDirectory = achievement.mod ?? "";
		#end

		if (Paths.fileExists('images/$image-pixel.png', IMAGE))
		{
			graphic = Paths.image('$image-pixel', false);
			hasAntialias = false;
		}
		else
			graphic = Paths.image(image, false);

		#if MODS_ALLOWED
		Mods.currentModDirectory = lastMod;
		#end

		if (graphic == null)
			graphic = Paths.image("unknownMod", false);

		final sizeX = 100;
		final sizeY = 100;

		final imgX = 15;
		final imgY = 15;
		final bitmap = graphic.bitmap;
		graphics.beginBitmapFill(bitmap, new Matrix(sizeX / bitmap.width, 0, 0, sizeY / bitmap.height, imgX, imgY), false, hasAntialias);
		graphics.drawRect(imgX, imgY, sizeX + 10, sizeY + 10);

		// achievement name/description
		var name = "Unknown";
		var desc = "Description not found";
		if (achievement != null)
		{
			name = achievement.name;
			desc = achievement.description;
		}

		final textX = sizeX + imgX + 15;
		final textY = imgY + 20;

		var text = new FlxText(0, 0, 270, "TEST!!!", 16);
		text.font = Paths.font("vcr.ttf");
		drawTextAt(text, name, textX, textY);
		drawTextAt(text, desc, textX, textY + 30);
		graphics.endFill();

		text.graphic.bitmap.dispose();
		text.graphic.bitmap.disposeImage();
		text.destroy();

		// other stuff
		FlxG.signals.preUpdate.add(update);
		FlxG.signals.gameResized.add(onResize);

		// FlxG.game.addChild(this); // Don't add it below mouse, or it will disappear once the game changes states
		FlxG.addChildBelowMouse(this); // dont care 🙄🥱

		// fix scale
		lastScale = (FlxG.stage.stageHeight / FlxG.height);
		this.x = 20 * lastScale;
		this.y = -130 * lastScale;
		this.scaleX = lastScale;
		this.scaleY = lastScale;
		intendedY = 20;
	}

	var bitmaps:Array<openfl.display.BitmapData> = [];
	function drawTextAt(text:FlxText, str:String, textX:Float, textY:Float)
	{
		text.text = str;
		text.updateHitbox();

		final clonedBitmap = text.graphic.bitmap.clone();
		bitmaps.push(clonedBitmap);
		graphics.beginBitmapFill(clonedBitmap, new Matrix(1, 0, 0, 1, textX, textY), false, false);
		graphics.drawRect(textX, textY, text.width + textX, text.height + textY);
	}
	
	var lerpTime:Float = 0;
	var countedTime:Float = 0;
	var timePassed:Float = -1;
	public var intendedY:Float = 0;

	function update()
	{
		if ((countedTime += FlxG.elapsed) < 3)
			y = ((FlxEase.elasticOut((lerpTime = Math.min(1, lerpTime + FlxG.elapsed))) * (intendedY + 130)) - 130) * lastScale;
		else
			if ((y -= FlxG.height * 2 * FlxG.elapsed * lastScale) <= -130 * lastScale)
				destroy();
	}

	function onResize(width:Int, height:Int)
	{
		final mult = height / FlxG.height;
		scaleX = scaleY = mult;
		x = (mult / lastScale) * x;
		y = (mult / lastScale) * y;
		lastScale = mult;
	}

	public function destroy()
	{
		Achievements._popups.remove(this);
		//trace('destroyed achievement, new count: ' + Achievements._popups.length);

		if (FlxG.game.contains(this))
			FlxG.game.removeChild(this);

		FlxG.signals.gameResized.remove(onResize);
		FlxG.signals.preUpdate.remove(update);
		deleteClonedBitmaps();
	}

	function deleteClonedBitmaps()
	{
		for (clonedBitmap in bitmaps)
			if (clonedBitmap != null)
			{
				clonedBitmap.dispose();
				clonedBitmap.disposeImage();
			}

		bitmaps = null;
	}
}
#end