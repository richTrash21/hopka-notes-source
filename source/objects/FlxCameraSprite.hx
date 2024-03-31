package objects;

import flixel.math.FlxRect;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxDirectionFlags;

// shit, but it's worked - Redar
@:access(flixel.FlxCamera)
@:access(openfl.display.Sprite)
class FlxCameraSprite extends FlxSprite{

	public var thisCamera(default, set):FlxCamera;

	@:noCompletion inline function set_thisCamera(e:FlxCamera):FlxCamera{
		if (thisCamera != null)	thisCamera.flashSprite.cacheAsBitmap = false;
		if (e != null)			e.flashSprite.cacheAsBitmap = true;
		return thisCamera = e;
	}

	@:noCompletion
	override function initVars():Void{
		super.initVars();
		thisCamera = FlxG.camera;
	}

	@:access(openfl.display.DisplayObject)
	public function new(x:Float = 0, y:Float = 0, ?aCamera:FlxCamera){
		super(x, y);
		dirty = true;
		if (aCamera != null) thisCamera = aCamera;
		thisCamera.flashSprite.cacheAsBitmap = true;
		FlxG.signals.gameResized.add(onGameResized);
		updateHitbox();
	}

	public function onGameResized(w:Int, h:Int) updateHitbox();

	inline public function updateOffset()
		return offset.set(-0.5 * (width - frameWidth), -0.5 * (height - frameHeight));

	override public function updateHitbox():Void
	{
		width = Math.abs(scale.x) * frameWidth / FlxG.scaleMode.scale.x;
		height = Math.abs(scale.y) * frameHeight / FlxG.scaleMode.scale.y;
		updateOffset();
		centerOrigin();
	}
	
	override public function destroy(){
		FlxG.signals.gameResized.remove(onGameResized);
		super.destroy();
	}

	override public function draw(){
		// 😭
		if (pixels != null && thisCamera.flashSprite.__cacheBitmap != null){
			pixels = thisCamera.flashSprite.__cacheBitmap.bitmapData;
			updateHitbox();
		}
		super.draw();
	}

	override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect{
		scale.scale(1/FlxG.scaleMode.scale.x, 1/FlxG.scaleMode.scale.y);
		var rect = super.getScreenBounds(newRect, camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
		return rect;
	}

	@:noCompletion override function drawSimple(camera:FlxCamera):Void{
		scale.scale(1/FlxG.scaleMode.scale.x, 1/FlxG.scaleMode.scale.y);
		super.drawSimple(camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
	}

	@:noCompletion override function drawComplex(camera:FlxCamera):Void{
		scale.scale(1/FlxG.scaleMode.scale.x, 1/FlxG.scaleMode.scale.y);
		super.drawComplex(camera);
		scale.scale(FlxG.scaleMode.scale.x, FlxG.scaleMode.scale.y);
	}

	override public function update(elapsed:Float):Void{
		#if FLX_DEBUG
		flixel.FlxBasic.activeCount++;
		#end
		last.set(x, y);

		if (path != null && path.active)
			path.update(elapsed);

		if (moves)
			updateMotion(elapsed);

		wasTouching = touching;
		touching = FlxDirectionFlags.NONE;
	}
}