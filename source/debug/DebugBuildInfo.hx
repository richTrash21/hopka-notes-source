package debug;

import debug.macro.BuildInfoMacro;

class DebugBuildInfo extends DebugTextField
{
	public function new(x = 0.0, y = 0.0, ?followObject:openfl.text.TextField)
	{
		super(x, y, followObject);
		this.text = "\n" + BuildInfoMacro.buildDate +
					"\n" + BuildInfoMacro.commit +
					"\n" + FlxG.VERSION +
					"\n" + BuildInfoMacro.openflVersion +
					"\n" + BuildInfoMacro.limeVersion;
	}
}