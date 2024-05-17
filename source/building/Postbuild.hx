package source.building; // Yeah, I know...

import sys.FileSystem;

/**
 * A script which executes after the game is built.
 * From official FNF repo.
 */
class Postbuild
{
	extern static inline final BUILD_TIME_FILE:String = ".build_time";

	static function main():Void
	{
		// get buildEnd before fs operations since they are blocking
		final end = Sys.time();
		if (FileSystem.exists(BUILD_TIME_FILE))
		{
			final fi = sys.io.File.read(BUILD_TIME_FILE);
			final start = fi.readDouble();
			fi.close();

			FileSystem.deleteFile(BUILD_TIME_FILE);

			trace("Build Finished! [" + (Math.round((end - start) * 100) * 0.01) + "s]");
		}
	}
}
