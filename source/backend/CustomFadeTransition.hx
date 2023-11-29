package backend;

class CustomFadeTransition extends flixel.FlxSubState
{
	static final colors:Array<Int> = [FlxColor.BLACK, FlxColor.BLACK, 0x0];
	public static var finishCallback:()->Void;
	public static var nextCamera:FlxCamera;

	public function new(duration:Float, isTransIn:Bool)
	{
		inline function finish(transIn:Bool) (!transIn && finishCallback != null) ? finishCallback() : close();
		/*if (duration <= 0)
		{
			finish(isTransIn);	// dont bother creating shit
			return;				// actually nvmd it soflocks you lmao
		}*/

		super();

		final zoom:Float = FlxMath.bound(FlxG.camera.zoom, 0.05, 1);
		final width:Int  = Std.int(FlxG.width / zoom);
		final height:Int = Std.int(FlxG.height / zoom);
		final realColors:Array<Int> = colors.copy();
		if (isTransIn) realColors.reverse();

		final transGradient:FlxSprite = flixel.util.FlxGradient.createGradientFlxSprite(1, height * 2, realColors);
		transGradient.setPosition((-width + FlxG.width) * 0.5, isTransIn ? -height : -height * 2);
		transGradient.scrollFactor.set();
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		add(transGradient).cameras = [nextCamera ?? FlxG.cameras.list[FlxG.cameras.list.length - 1]]; // actually uses nextCamera now WOW!!!!
		nextCamera = null;

		FlxTween.tween(transGradient, {y: (isTransIn ? height : 0)}, duration, {onComplete: function(_) finish(isTransIn)});
	}
}