package objects;

import flixel.animation.FlxAnimation;
import flixel.math.FlxPoint;
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

	public var onGraphicLoaded:()->Void;
	public var animOffsets:Map<String, FlxPoint> = [];
	public var curAnimOffset(get, never):Null<FlxPoint>;

	public var deltaX(default, null):Float;
	public var deltaY(default, null):Float;

	public var RIGHT(get, never):Float;
	public var BOTTOM(get, never):Float;

	public var inBounds(default, null):Bool;
	public var boundBox(default, set):FlxRect;
	public var onEnterBounds:()->Void;
	public var onLeaveBounds:()->Void;

	var __drawingWithOffset = false;

	public function new(?x = 0., ?y = 0., ?simpleGraphic:flixel.system.FlxAssets.FlxGraphicAsset, ?antialiasing = true):Void
	{
		super(x, y, simpleGraphic is String ? Paths.image(simpleGraphic) : simpleGraphic);
		this.antialiasing = ClientPrefs.data.antialiasing ? antialiasing : false;
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
				onEnterBounds();
			else if (!inBounds && onLeaveBounds != null)
				onLeaveBounds();
		}
	}

	override public function destroy():Void
	{
		for (anim => offset in animOffsets)
			offset.put();

		animOffsets = CoolUtil.clear(animOffsets);
		boundBox = flixel.util.FlxDestroyUtil.put(boundBox);
		onGraphicLoaded = null;
		onEnterBounds = null;
		onLeaveBounds = null;
		super.destroy();
	}

	public function playAnim(name:String, forced = false, ?reverse = false, ?startFrame = 0):Void
	{
		// if there is no animation named "Name" then just skips the whole shit
		if (name == null || !animation.exists(name))
		{
			FlxG.log.warn('No animation called "$name"');
			return;
		}
		animation.play(name, forced, reverse, startFrame);
		
		/*if (animOffsets.exists(Name))
			offset.copyFrom(animOffsets.get(Name));*/
	}

	// quick n' easy animation setup
	/*inline*/ public function addAnim(name:String, ?prefix:String, ?indices:Array<Int>, frameRate = 24., looped = true,
			?flipX = false, ?flipY = false, ?loopPoint = 0):FlxAnimation
	{
		if (prefix != null)
		{
			if (indices?.length == 0)
				animation.addByPrefix(name, prefix, frameRate, looped, flipX, flipY);
			else
				animation.addByIndices(name, prefix, indices, "", frameRate, looped, flipX, flipY);
		}
		else if (indices?.length > 0)
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

	/**
		Updates the sprite's hitbox (`width`, `height`, `offset`) according to the current `scale`.
		Also calls `centerOrigin()`.
	**/
	override public function updateHitbox():Void
	{
		width = Math.abs(scale.x) * frameWidth;
		height = Math.abs(scale.y) * frameHeight;
		updateOfsset();
		centerOrigin();
	}

	/**
		A part from updateHitbox() that gives sprites propper offset.
		@return Adjusted offset.
	**/
	inline public function updateOfsset():FlxPoint
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

	// bunch of overrides to implement animation offsets
	/*override public function draw()
	{
		if (alpha == 0 || _frame.type == flixel.graphics.frames.FlxFrame.FlxFrameType.EMPTY)
			return;

		if (animation.curAnim == null)
		{
			super.draw();
			return;
		}

		// get current animation's offsets
		final __offset = animOffsets.get(animation.curAnim.name);
		// add them to the current one's
		if (__offset != null)
			offset.addPoint(__offset);
		// draw sprite
		super.draw();
		// revert
		if (__offset != null)
			offset.subtractPoint(__offset);
	}*/

	@:noCompletion override function drawSimple(camera:FlxCamera):Void
	{
		// skip if no animation is playing (it's null) or there is no offset for this animation
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name))
			return super.drawSimple(camera);

		__drawingWithOffset = true;
		final __offset = curAnimOffset; // get current animation's offsets
		offset.addPoint(__offset);		// add them to the current one's
		super.drawSimple(camera);		// draw sprite
		offset.subtractPoint(__offset);	// revert
		__drawingWithOffset = false;
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void
	{
		// skip if no animation is playing (it's null) or there is no offset for this animation
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name))
			return super.drawComplex(camera);

		__drawingWithOffset = true;
		// get current animation's offsets
		final __offset = curAnimOffset; // get current animation's offsets
		offset.addPoint(__offset);		// add them to the current one's
		super.drawComplex(camera);		// draw sprite
		offset.subtractPoint(__offset);	// revert
		__drawingWithOffset = false;
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) || __drawingWithOffset)
			return super.getScreenBounds(newRect, camera);

		final __offset = curAnimOffset;						// get current animation's offsets
		offset.addPoint(__offset);							// add them to the current one's
		final ret = super.getScreenBounds(newRect, camera);	// super
		offset.subtractPoint(__offset);						// revert
		return ret;
	}

	override public function transformWorldToPixelsSimple(worldPoint:FlxPoint, ?result:FlxPoint):FlxPoint
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) || __drawingWithOffset)
			return super.transformWorldToPixelsSimple(worldPoint, result);

		// get current animation's offsets
		final __offset = animOffsets.get(animation.curAnim.name);
		offset.addPoint(__offset);											// add them to the current one's
		final ret = super.transformWorldToPixelsSimple(worldPoint, result);	// super
		offset.subtractPoint(__offset);										// revert
		return ret;
	}

	override public function transformWorldToPixels(worldPoint:FlxPoint, ?camera:FlxCamera, ?result:FlxPoint):FlxPoint
	{
		if (animation.curAnim == null || !animOffsets.exists(animation.curAnim.name) || __drawingWithOffset)
			return super.transformWorldToPixels(worldPoint, camera, result);

		// get current animation's offsets
		final __offset = animOffsets.get(animation.curAnim.name);
		offset.addPoint(__offset);												// add them to the current one's
		final ret = super.transformWorldToPixels(worldPoint, camera, result);	// super
		offset.subtractPoint(__offset);											// revert
		return ret;
	}

	@:noCompletion inline function get_curAnimOffset():Null<FlxPoint>
	{
		return animation.curAnim == null ? null : animOffsets.get(animation.curAnim.name);
	}

	@:noCompletion inline function set_boundBox(Rect:FlxRect):FlxRect
	{
		if (Rect != null)
			inBounds = objectInRect(this, Rect);
		return boundBox = Rect;
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
