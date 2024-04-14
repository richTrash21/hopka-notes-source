package backend.flixel;

class CustomCameraFrontEnd extends flixel.system.frontEnds.CameraFrontEnd
{
	// needed only for this override
	// that's all
	@:access(flixel.FlxCamera._defaultCameras)
	override public function reset(?newCamera:FlxCamera):Void
	{
		while (list.length != 0)
			remove(list[0]);

		if (newCamera == null)
			newCamera = new objects.GameCamera();

		FlxG.camera = add(newCamera);
		newCamera.ID = 0;

		FlxCamera._defaultCameras = defaults;
	}
}