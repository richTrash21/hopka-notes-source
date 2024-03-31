package objects;

import flixel.animation.FlxAnimation;
import flixel.util.FlxArrayUtil;
import flixel.math.FlxRect;

/**
	An extended FlxSprite with a bunch of helper functions and other stuff
**/
class ExtendedSprite extends FlxSprite
{
	static final __animsHelper = new Array<String>();

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

	// by redar
	public static function autoAnimations<T:FlxSprite>(sprite:T, animIndex = -1):T
	{
		FlxArrayUtil.clearArray(__animsHelper);
		if (sprite != null && sprite.frames != null && sprite.frames.numFrames != 0)
		{
			var name:String = null;
			var prevAnim:String;
			for (anim in sprite.frames.framesHash.keys())
			{
				prevAnim = name;
				name = anim.substr(0, anim.length - 4);
				if (name != prevAnim) // !__animsHelper.contains(name)
				{
					__animsHelper.push(name);
					sprite.animation.addByPrefix(name, name, 24, true);
				}
			}

			if (animIndex > -1)
				sprite.animation.play(__animsHelper[FlxMath.minInt(animIndex, __animsHelper.length)]);
		}
		else
			trace("No animations found, damn... :(");

		return sprite;
	}

	public var onGraphicLoaded:()->Void;
	public var animOffsets:Map<String, FlxPoint> = [];
	// public var curAnimOffset(get, never):Null<FlxPoint>;

	public var deltaX(default, null):Float;
	public var deltaY(default, null):Float;

	public var RIGHT(get, never):Float;
	public var BOTTOM(get, never):Float;

	public var inBounds(default, null):Bool;
	public var boundBox(default, set):FlxRect;
	public var onEnterBounds:(sprite:FlxSprite)->Void;
	public var onLeaveBounds:(sprite:FlxSprite)->Void;

	var __drawingWithOffset = false;

	public function new(?x = 0., ?y = 0., ?simpleGraphic:flixel.system.FlxAssets.FlxGraphicAsset, ?antialiasing = true):Void
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
			return; // no bound box/movement flag - skip whole shit
	
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
		super.destroy();
	}

	public function playAnim(name:String, forced = false, ?reverse = false, ?startFrame = 0):Void
	{
		// if there is no animation named "name" then just skips the whole shit
		if (name == null || !animExists(name))
		{
			final txt = 'No animation called "$name"';
			return #if debug FlxG.log.warn(txt) #else trace(txt) #end;
		}

		animation.play(name, forced, reverse, startFrame);
	}

	// quick n' easy animation setup
	/*inline*/ public function addAnim(name:String, ?prefix:String, ?indices:Array<Int>, frameRate = 24., looped = true,
			?flipX = false, ?flipY = false, ?loopPoint = 0):FlxAnimation
	{
		final indicesEmpty = (indices == null || indices.length == 0);
		if (prefix != null)
		{
			if (indicesEmpty)
				animation.addByPrefix(name, prefix, frameRate, looped, flipX, flipY);
			else
				animation.addByIndices(name, prefix, indices, "", frameRate, looped, flipX, flipY);
		}
		else if (!indicesEmpty)
			animation.add(name, indices, frameRate, looped, flipX, flipY);

		final addedAnim = getAnimByName(name);
		if (addedAnim != null)
		{
			addedAnim.loopPoint = loopPoint; // better than -loop anims lmao
		}
		return addedAnim;
	}

	inline public function animExists(name:String):Bool
	{
		return animation.exists(name);
	}

	inline public function getAnimByName(name:String):FlxAnimation
	{
		return animation.getByName(name);
	}

	/*public function getScaledGraphicMidpoint(?point:FlxPoint):FlxPoint
	{
		if (point == null)
			point = FlxPoint.get();
		return point.set(x + (frameWidth * scale.x) * 0.5, y + (frameHeight * scale.y) * 0.5);
	}*/

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

	inline public function addOffset(name:String, x:Float, y:Float):FlxPoint
	{
		if (animOffsets.exists(name))
			return animOffsets.get(name).set(x, y);

		final point = FlxPoint.get(x, y);
		animOffsets.set(name, point);
		return point;
	}

	@:noCompletion override function drawSimple(camera:FlxCamera):Void
	{
		// skip if no animation is playing (it's null) or there is no offset for this animation
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name))
			return super.drawSimple(camera);

		__drawingWithOffset = true;
		final offset = animOffsets.get(animation.curAnim.name);	// get current animation's offsets
		this.offset.addPoint(offset);							// add them to the current one's
		super.drawSimple(camera);								// draw sprite
		this.offset.subtractPoint(offset);						// revert
		__drawingWithOffset = false;
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void
	{
		// skip if no animation is playing (it's null) or there is no offset for this animation
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name))
			return super.drawComplex(camera);

		__drawingWithOffset = true;
		// get current animation's offsets
		final offset = animOffsets.get(animation.curAnim.name);	// get current animation's offsets
		this.offset.addPoint(offset);							// add them to the current one's
		super.drawComplex(camera);								// draw sprite
		this.offset.subtractPoint(offset);						// revert
		__drawingWithOffset = false;
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) || __drawingWithOffset)
			return super.getScreenBounds(newRect, camera);

		final offset = animOffsets.get(animation.curAnim.name);	// get current animation's offsets
		this.offset.addPoint(offset);							// add them to the current one's
		final ret = super.getScreenBounds(newRect, camera);		// super
		this.offset.subtractPoint(offset);						// revert
		return ret;
	}

	override public function transformWorldToPixelsSimple(worldPoint:FlxPoint, ?result:FlxPoint):FlxPoint
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) /*|| __drawingWithOffset*/)
			return super.transformWorldToPixelsSimple(worldPoint, result);

		// get current animation's offsets
		final offset = animOffsets.get(animation.curAnim.name);
		this.offset.addPoint(offset);										// add them to the current one's
		final ret = super.transformWorldToPixelsSimple(worldPoint, result);	// super
		this.offset.subtractPoint(offset);									// revert
		return ret;
	}

	override public function transformWorldToPixels(worldPoint:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) /*|| __drawingWithOffset*/)
			return super.transformWorldToPixels(worldPoint, camera, result);

		// get current animation's offsets
		final offset = animOffsets.get(animation.curAnim.name);
		this.offset.addPoint(offset);											// add them to the current one's
		final ret = super.transformWorldToPixels(worldPoint, camera, result);	// super
		this.offset.subtractPoint(offset);										// revert
		return ret;
	}

	/*@:noCompletion inline function get_curAnimOffset():Null<FlxPoint>
	{
		return animation.curAnim == null ? null : animOffsets.get(animation.curAnim.name);
	}*/

	@:noCompletion inline function set_boundBox(rect:FlxRect):FlxRect
	{
		if (rect != null)
			inBounds = objectInRect(this, rect);
		return boundBox = rect;
	}

	@:noCompletion inline function get_RIGHT():Float
	{
		return x + width;
	}

	@:noCompletion inline function get_BOTTOM():Float
	{
		return y + height;
	}
}

/*@:transitive
@:multiType(@:followWithAbstracts K)
abstract OffsetMap(Map<String, FlxPoint>) from Map<String, FlxPoint> to Map<String, FlxPoint>
{
	public function new();

	inline public function set(k:String, x:Float = 0, y:Float = 0):FlxPoint
	{
		this.set(k, FlxPoint.get(x, y));
		return this.get(k);
	}

	@:arrayAccess inline public function get(k:String):FlxPoint
	{
		return this.get(k);
	}

	inline public function exists(k:String):Bool
	{
		return this.exists(k);
	}

	inline public function remove(k:String):Bool
	{
		if (this.exists(k))
			this.get(k).put();

		return this.remove(k);
	}

	inline public function keys():Iterator<String>
	{
		return this.keys();
	}

	inline public function iterator():Iterator<FlxPoint>
	{
		return this.iterator();
	}

	inline public function copy():OffsetMap
	{
		return cast [for (k => v in this) k => v.clone()];
	}

	inline public function toString():String
	{
		return this.toString();
	}

	inline public function clear():Void
	{
		for (v in this.iterator())
			v.put();

		this.clear();
	}
}*/
