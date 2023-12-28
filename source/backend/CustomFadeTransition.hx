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

		final daCamera:FlxCamera = nextCamera ?? FlxG.cameras.list[FlxG.cameras.list.length - 1];
		cameras = [daCamera]; // actually uses nextCamera now WOW!!!!
		nextCamera = null;

		final width:Float  = daCamera.width  / daCamera.scaleX;
		final height:Float = daCamera.height / daCamera.scaleY;
		final realColors:Array<Int> = colors.copy();
		if (isTransIn) realColors.reverse();

		final deltaHeight:Float = daCamera.height - height;
		final transGradient:FlxSprite = flixel.util.FlxGradient.createGradientFlxSprite(1, Std.int(height) * 2, realColors);
		transGradient.setPosition((daCamera.width - width) * 0.5, isTransIn ? -(height + deltaHeight) : -(height + deltaHeight) * 2);
		transGradient.scrollFactor.set();
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		add(transGradient);

		FlxTween.tween(transGradient, {y: (isTransIn ? height : 0)}, duration, {onComplete: function(_) finish(isTransIn)});
	}
}