package backend;

#if VIDEOS_ALLOWED
#if hxCodec
/**
 * This class will play the video in the form of a FlxSprite, which you can control.
 */
class VideoSprite extends flixel.FlxSprite
{
	public var readyCallback:()->Void;
	public var finishCallback:()->Void;
	public var isPlaying(get, never):Bool;

	public var autoScale:Bool;
	var video:VideoHandler;

	public function new(VideoWidth:Float = 320, VideoHeight:Float = 240, AutoScale:Bool = true)
	{
		super(); // so that stupid haxeflixel graphic won't show up
		visible = false;
		
		video = new VideoHandler(VideoWidth, VideoHeight, autoScale = AutoScale);
		video.visible = false;

		video.readyCallback = () ->
		{
			visible = true;
			loadGraphic(video.bitmapData);
			FlxG.cameras.cameraResized.add(cameraResized);
			adjustSize();

			if (readyCallback != null)
				readyCallback();
		}

		video.finishCallback = () ->
		{
			if (finishCallback != null)
				finishCallback();

			FlxG.cameras.cameraResized.remove(cameraResized);
			destroy();
		};
		scrollFactor.set();
	}

	function cameraResized(camera:FlxCamera)
	{
		if (camera == this.camera)
			adjustSize();
	}

	function adjustSize()
	{
		if (autoScale)
		{
			setGraphicSize(camera.width / camera.scaleX, camera.height / camera.scaleY);
			updateHitbox();
			screenCenter();
		}
	}

	override public function destroy()
	{
		readyCallback = null;
		finishCallback = null;
		// video.finishVideo();
		video = null;
		super.destroy();
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	inline public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false)
	{
		video.playVideo(path, repeat, pauseMusic);
	}

	inline public function pause()
	{
		video.pause();
	}

	inline public function resume()
	{
		video.resume();
	}

	@:noCompletion inline function get_isPlaying():Bool
	{
		return video?.isPlaying;
	}
}
#else
typedef VideoSprite = hxvlc.flixel.FlxVideoSprite;
#end
#end
