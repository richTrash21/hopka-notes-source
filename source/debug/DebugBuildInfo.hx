package debug;

import debug.macro.BuildInfoMacro;

class DebugBuildInfo extends DebugTextField
{
	public function new(x = 0.0, y = 0.0, ?followObject:openfl.text.TextField)
	{
		super(x, y, followObject);
		_text = "\nBuild Date: " + BuildInfoMacro.buildDate;
		_text += "\nCommit " + BuildInfoMacro.commitNumber + " (" + BuildInfoMacro.commitHash + ")";
		_text += "\n" + FlxG.VERSION;
		_text += "\n" + BuildInfoMacro.openflVersion;
		_text += "\n" + BuildInfoMacro.limeVersion;
		this.text = _text;
	}
}