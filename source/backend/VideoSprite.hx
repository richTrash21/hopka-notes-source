package backend;

import openfl.display.BitmapData;

/**
 * This class will play the video in the form of a FlxSprite, which you can control.
 */
class VideoSprite extends flixel.FlxSprite
{
	public var readyCallback:()->Void;
	public var finishCallback:()->Void;
	public var isPlaying(get, never):Bool;
	@:noCompletion inline function get_isPlaying() return (video == null ? false : video.isPlaying);

	public var autoScale:Bool;
	var video:VideoHandler;

	public function new(VideoWidth:Float = 320, VideoHeight:Float = 240, AutoScale:Bool = true)
	{
		super(); // so that stupid haxeflixel graphic won't show up
		visible = false;
		
		video = new VideoHandler(VideoWidth, VideoHeight, autoScale = AutoScale);
		video.visible = false;
		//FlxG.game.removeChild(video);

		video.readyCallback = function()
		{
			visible = true;
			loadGraphic(video.bitmapData);
			FlxG.cameras.cameraResized.add(cameraResized);

			if (readyCallback != null)
				readyCallback();
		}

		video.finishCallback = function()
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
		if (autoScale && camera == this.camera)
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
		video = null;
		super.destroy();
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
