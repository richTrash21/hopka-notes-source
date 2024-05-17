package source.building; // Yeah, I know...

/**
 * A script which executes before the game is built.
 * From official FNF repo.
 */
class Prebuild
{
	extern static inline final BUILD_TIME_FILE:String = ".build_time";

	static function main():Void
	{
		final fo = sys.io.File.write(BUILD_TIME_FILE);
		fo.writeDouble(Sys.time());
		fo.close();
		trace("Building...");
	}
}
