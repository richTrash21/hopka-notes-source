package objects;

import flixel.math.FlxRect;

// shit, but it's worked - Redar
// works* - rich
@:access(flixel.FlxCamera)
@:access(openfl.display.Sprite)
class FlxCameraSprite extends flixel.FlxSprite
{
	public var thisCamera(default, set):FlxCamera;

	@:access(openfl.display.DisplayObject)
	public function new(x = 0.0, y = 0.0, ?camera:FlxCamera)
	{
		super(x, y);
		thisCamera = camera;
		FlxG.signals.gameResized.add(onGameResized);
		updateHitbox();
	}

	public function onGameResized(w:Int, h:Int):Void
	{
		updateHitbox();
	}

	override public function updateHitbox():Void
	{
		width = Math.abs(scale.x) * frameWidth / FlxG.scaleMode.scale.x;
		height = Math.abs(scale.y) * frameHeight / FlxG.scaleMode.scale.y;
		updateOffset();
		centerOrigin();
	}

	inline public function updateOffset():FlxPoint
	{
		return offset.set(-0.5 * (width - frameWidth), -0.5 * (height - frameHeight));
	}
	
	override public function destroy()
	{
		FlxG.signals.gameResized.remove(onGameResized);
		super.destroy();
	}

	override public function update(elapsed:Float):Void
	{
		#if FLX_DEBUG
		flixel.FlxBasic.activeCount++;
		#end
		last.set(x, y);

		if (path != null && path.active)
			path.update(elapsed);

		if (moves)
			updateMotion(elapsed);

		wasTouching = touching;
		touching = NONE;
	}

	override public function draw()
	{
		// 😭 - Redar
		// понимаю бро...😔😔 - rich
		if (pixels != null && thisCamera.flashSprite.__cacheBitmap != null)
		{
			pixels = thisCamera.flashSprite.__cacheBitmap.bitmapData;
			updateHitbox();
		}
		super.draw();

		/*checkEmptyFrame();

		if (alpha == 0 || _frame.type == EMPTY)
			return;

		if (dirty) // rarely
			calcFrame(useFramePixels);

		// no cameras iteration since this sprite is the camera
		if (camera.visible && camera.exists && !isOnScreen(camera))
		{
			if (isSimpleRender(camera))
				drawSimple(camera);
			else
				drawComplex(camera);
		}

		#if FLX_DEBUG
		flixel.FlxBasic.visibleCount++;
		#end

		#if FLX_DEBUG
		if (FlxG.debugger.drawDebug)
			drawDebug();
		#end*/
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect
	{
		scale.scale(1 / FlxG.scaleMode.scale.x, 1 / FlxG.scaleMode.scale.y);
		var rect = super.getScreenBounds(newRect, camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
		return rect;
	}

	@:noCompletion override function drawSimple(camera:FlxCamera):Void
	{
		scale.scale(1 / FlxG.scaleMode.scale.x, 1 / FlxG.scaleMode.scale.y);
		super.drawSimple(camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void
	{
		scale.scale(1 / FlxG.scaleMode.scale.x, 1 / FlxG.scaleMode.scale.y);
		super.drawComplex(camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
	}

	/*@:noCompletion override inline function get_camera():FlxCamera
	{
		return _cameras[0];
	}

	@:noCompletion override inline function set_camera(camera:FlxCamera):FlxCamera
	{
		return _cameras[0] = camera;
	}

	@:noCompletion override inline function get_cameras():Array<FlxCamera>
	{
		return _cameras;
	}

	@:noCompletion override inline function set_cameras(cameras:Array<FlxCamera>):Array<FlxCamera>
	{
		return _cameras = cameras;
	}*/

	@:noCompletion function set_thisCamera(camera:FlxCamera):FlxCamera
	{
		if (thisCamera != camera)
		{
			if (thisCamera != null)
				thisCamera.flashSprite.cacheAsBitmap = false;
			if (camera != null)
				camera.flashSprite.cacheAsBitmap = true;

			thisCamera = camera;
		}
		return camera;
	}
}