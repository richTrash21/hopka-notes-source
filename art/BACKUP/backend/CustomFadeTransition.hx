package backend;

class CustomFadeTransition extends flixel.FlxSubState
{
	static final colors = [FlxColor.BLACK, FlxColor.BLACK, 0x0];
	public static var finishCallback:()->Void;
	public static var nextCamera:FlxCamera;

	public function new(duration:Float, isTransIn:Bool)
	{
		inline function finish(transIn:Bool)
		{
			if (finishCallback == null || transIn)
				close();
			else
				finishCallback();
		}
		/*if (duration <= 0)
		{
			finish(isTransIn);	// dont bother creating shit
			return;				// actually nvmd it soflocks you lmao
		}*/

		super();

		final camera = nextCamera ?? FlxG.cameras.list[FlxG.cameras.list.length - 1];
		this.camera = camera; // actually uses nextCamera now WOW!!!!
		nextCamera = null;

		final width  = camera.width  / camera.scaleX;
		final height = camera.height / camera.scaleY;
		final realColors = colors.copy();
		if (isTransIn)
			realColors.reverse();

		final deltaHeight = camera.height - height;
		final transGradient = flixel.util.FlxGradient.createGradientFlxSprite(1, Std.int(height) * 2, realColors);
		transGradient.setPosition((camera.width - width) * 0.5, isTransIn ? -(height + deltaHeight) : -(height + deltaHeight) * 2);
		transGradient.scrollFactor.set();
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		add(transGradient);

		FlxTween.tween(transGradient, {y: (isTransIn ? height : 0)}, duration, {onComplete: (_) -> finish(isTransIn)});
	}
}