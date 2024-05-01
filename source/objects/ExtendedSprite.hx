package objects;

import flixel.animation.FlxAnimation;
import flixel.util.FlxArrayUtil;
import flixel.math.FlxRect;

/**
	An extended FlxSprite with a bunch of helper functions and other stuff
**/
class ExtendedSprite extends FlxSprite
{
	/**
		Checks if object is in the rectangles bounds.

		@param    object   Object to check.
		@param    rect     Rectangle to check.

		@return   Is sprite in the rectangle.
	**/
	inline public static function objectInRect(object:flixel.FlxObject, rect:FlxRect):Bool
	{
		return rect.overlaps(object.getHitbox(FlxRect.weak()));
	}
	
	/**
		Precahces given sprite by setting low alpha value and calling draw.
		@return  Given sprite
	**/
	inline public static function precache<T:FlxSprite>(sprite:T):T
	{
		if (sprite != null)
		{
			final originalAlpha = sprite.alpha;
			sprite.alpha = 0.00001;
			sprite.draw();
			sprite.alpha = originalAlpha;
		}
		return sprite;
	}

	inline public static function scaleBySize<T:FlxSprite>(sprite:T, ?maxWidth:Float, ?maxHeight:Float):T
	{
		if (sprite != null)
		{
			if (maxWidth == null)
				maxWidth = FlxG.width;
			if (maxHeight == null)
				maxHeight = FlxG.height;

			final ratio1 = sprite.width / sprite.height;
			final ratio2 = FlxG.width / FlxG.height;
			sprite.setGraphicSize(ratio1 >= ratio2 ? maxWidth : 0.0, ratio2 >= ratio1 ? maxHeight : 0.0);
		}
		return sprite;
	}

	// by redar13
	inline public static function autoAnimations<T:FlxSprite>(sprite:T, animIndex = -1):T
	{
		if (sprite == null || sprite.frames == null || sprite.frames.numFrames == 0)
			GameLog.notice("No animations found, damn... :(");
		else
		{
			var i = -1;
			var name:String;
			for (anim in sprite.frames.framesHash.keys())
			{
				name = anim.substr(0, anim.length - 4);
				if (!sprite.animation.exists(name))
				{
					sprite.animation.addByPrefix(name, name, 24, true);
					if (++i == animIndex)
						sprite.animation.play(name);
				}
			}
		}
		return sprite;
	}

	public var onGraphicLoaded:()->Void;
	public var animOffsets:Map<String, FlxPoint> = new Map();

	public var deltaX(default, null):Float;
	public var deltaY(default, null):Float;

	public var inBounds(default, null):Bool;
	public var boundBox(default, set):FlxRect;
	public var onEnterBounds:(sprite:FlxSprite)->Void;
	public var onLeaveBounds:(sprite:FlxSprite)->Void;

	// some drawing related stuff
	var __drawingWithOffset = false;
	var __drawingOffset:FlxPoint;
	var __anim:String;

	public function new(x = 0., y = 0., ?simpleGraphic:flixel.system.FlxAssets.FlxGraphicAsset, antialiasing = true):Void
	{
		super(x, y, Paths.resolveGraphicAsset(simpleGraphic));
		this.antialiasing = ClientPrefs.data.antialiasing && antialiasing;
	}

	override public function graphicLoaded():Void
	{
		if (onGraphicLoaded != null)
			onGraphicLoaded();
	}

	override public function update(elapsed:Float):Void
	{
		deltaX = x - last.x;
		deltaY = y - last.y;

		super.update(elapsed);
		if (boundBox == null || !moves)
			return; // no bound box/movement flag - skip
	
		final lastInBounds = inBounds;
		inBounds = objectInRect(this, boundBox);
		if (lastInBounds != inBounds)
		{
			if (inBounds && onEnterBounds != null)
				onEnterBounds(this);
			else if (!inBounds && onLeaveBounds != null)
				onLeaveBounds(this);
		}
	}

	override public function destroy():Void
	{
		if (animOffsets != null)
			for (anim => offset in animOffsets)
			{
				offset.put();
				animOffsets.remove(anim);
			}

		animOffsets = null;
		boundBox = flixel.util.FlxDestroyUtil.put(boundBox);
		onGraphicLoaded = null;
		onEnterBounds = null;
		onLeaveBounds = null;
		__drawingOffset = null;
		super.destroy();
	}

	public function playAnim(name:String, forced = false, reverse = false, startFrame = 0):Void
	{
		// if there is no animation named "name" then just skips the whole shit
		if (name == null || !animation.exists(name))
			return GameLog.warn('No animation called "$name"');

		animation.play(name, forced, reverse, startFrame);
	}

	// quick n' easy animation setup
	public function addAnim(name:String, ?prefix:String, ?indices:Array<Int>, frameRate = 24., looped = true, flipX = false, flipY = false, loopPoint = 0):FlxAnimation
	{
		final indicesEmpty = (indices == null || indices.length == 0);
		if (prefix == null && indicesEmpty)
		{
			GameLog.warn('Can\'t add anim "$name", no prefix or indices was geven!');
			return null;
		}

		if (prefix != null)
		{
			if (indicesEmpty)
				animation.addByPrefix(name, prefix, frameRate, looped, flipX, flipY);
			else
				animation.addByIndices(name, prefix, indices, "", frameRate, looped, flipX, flipY);
		}
		else if (!indicesEmpty)
			animation.add(name, indices, frameRate, looped, flipX, flipY);

		final addedAnim = animation.getByName(name);
		if (addedAnim != null)
		{
			addedAnim.loopPoint = loopPoint; // better than -loop anims lmao
		}
		return addedAnim;
	}

	// kinda like setGraphicSize, but with just scale value
	inline public function setScale(x:Float, ?y:Float):FlxPoint
	{
		return scale.set(x, y ?? x);
	}

	public function addPosition(addX:Float, addY:Float):Void
	{
		x += addX;
		y += addY;
	}

	public function subtractPosition(addX:Float, addY:Float):Void
	{
		x -= addX;
		y -= addY;
	}

	/**
		Updates the sprite's hitbox (`width`, `height`, `offset`) according to the current `scale`.
		Also calls `centerOrigin()`.
	**/
	override public function updateHitbox():Void
	{
		width = Math.abs(scale.x) * frameWidth;
		height = Math.abs(scale.y) * frameHeight;
		updateOffset();
		centerOrigin();
	}

	/**
		A part from updateHitbox() that gives sprites propper offset.
		@return Adjusted offset.
	**/
	inline public function updateOffset():FlxPoint
	{
		return offset.set(-0.5 * (width - frameWidth), -0.5 * (height - frameHeight));
	}

	public function addOffset(name:String, x:Float, y:Float):FlxPoint
	{
		if (animOffsets.exists(name))
			return animOffsets[name].set(x, y);

		final point = FlxPoint.get(x, y);
		animOffsets[name] = point;
		return point;
	}

	@:noCompletion override function drawSimple(camera:FlxCamera):Void
	{
		__drawingWithOffset = true;
		__update__drawing__offset();  // get current animation's offsets
		__add__drawing__offset();	  // add them to the current one's
		super.drawSimple(camera);	  // draw sprite
		__remove__drawing__offset();  // revert
		__drawingWithOffset = false;
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void
	{
		__drawingWithOffset = true;
		__update__drawing__offset();  // get current animation's offsets
		__add__drawing__offset();	  // add them to the current one's
		super.drawComplex(camera);	  // draw sprite
		__remove__drawing__offset();  // revert
		__drawingWithOffset = false;
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (__drawingWithOffset)
			return super.getScreenBounds(newRect, camera);

		__update__drawing__offset();
		__add__drawing__offset();
		final ret = super.getScreenBounds(newRect, camera);
		__remove__drawing__offset();
		return ret;
	}

	override public function transformWorldToPixelsSimple(worldPoint:FlxPoint, ?result:FlxPoint):FlxPoint
	{
		// if (__drawingWithOffset)
		//	return super.transformWorldToPixelsSimple(worldPoint, result);

		__update__drawing__offset();
		__add__drawing__offset();
		final ret = super.transformWorldToPixelsSimple(worldPoint, result);
		__remove__drawing__offset();
		return ret;
	}

	override public function transformWorldToPixels(worldPoint:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		// if (__drawingWithOffset)
		//	return super.transformWorldToPixels(worldPoint, camera, result);

		__update__drawing__offset();
		__add__drawing__offset();
		final ret = super.transformWorldToPixels(worldPoint, camera, result);
		__remove__drawing__offset();
		return ret;
	}

	@:noCompletion extern inline function __update__drawing__offset()
	{
		if (animation.curAnim == null)
		{
			__anim = null;
			__drawingOffset = null;
		}
		else if (__anim != animation.curAnim.name)
		{
			__anim = animation.curAnim.name;
			__drawingOffset = animOffsets[__anim];
		}
	}

	@:noCompletion extern inline function __add__drawing__offset()
	{
		if (__drawingOffset != null)
			offset.addPoint(__drawingOffset);
	}

	@:noCompletion extern inline function __remove__drawing__offset()
	{
		if (__drawingOffset != null)
			offset.subtractPoint(__drawingOffset);
	}

	@:noCompletion inline function set_boundBox(rect:FlxRect):FlxRect
	{
		if (rect != null)
			inBounds = objectInRect(this, rect);
		return boundBox = rect;
	}
}
