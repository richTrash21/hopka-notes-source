package backend;

import openfl.display.BitmapData;

/**
 * This class will play the video in the form of a FlxSprite, which you can control.
 */
class VideoSprite extends flixel.FlxSprite
{
	static final _placeholder:BitmapData = new BitmapData(FlxG.width, FlxG.height, true, FlxColor.BLACK);

	public var readyCallback:()->Void;
	public var finishCallback:()->Void;
	public var isPlaying(get, never):Bool;
	@:noCompletion inline function get_isPlaying() return (video == null ? false : video.isPlaying);

	public var autoScale:Bool;
	var video:VideoHandler;

	public function new(VideoWidth:Float = 320, VideoHeight:Float = 240, AutoScale:Bool = true)
	{
		super(_placeholder); // so that stupid haxeflixel graphic won't show up
		setupVideo(VideoWidth, VideoHeight, AutoScale);
	}

	override public function draw()
	{
		if (isPlaying && autoScale)
		{
			setGraphicSize(FlxG.width / camera.zoom, FlxG.height / camera.zoom);
			updateHitbox();
			screenCenter();
		}
		super.draw();
	}

	// for sprite reusing
	public function setupVideo(Width:Float = 320, Height:Float = 240, AutoScale:Bool = true)
	{
		video = new VideoHandler(Width, Height, autoScale = AutoScale);
		video.visible = false;

		video.readyCallback = function()
		{
			loadGraphic(video.bitmapData);

			if (readyCallback != null)
				readyCallback();
		}

		video.finishCallback = function()
		{
			if (finishCallback != null)
				finishCallback();

			destroy();
		};
	}

	/**
	 * Native video support for Flixel & OpenFL
	 * @param path Example: `your/video/here.mp4`
	 * @param repeat Repeat the video.
	 * @param pauseMusic Pause music until done video.
	 */
	public function playVideo(path:String, ?repeat:Bool = false, pauseMusic:Bool = false)
		video.playVideo(path, repeat, pauseMusic);

	public function pause()  video.pause();
	public function resume() video.resume();
}
