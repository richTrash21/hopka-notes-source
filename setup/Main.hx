package;


typedef Library = {name:String, type:String, version:String, dir:String, ref:String, url:String}

class Main
{
	public static function main():Void
	{
		// Create a folder to prevent messing with hmm libraries
		/*if (!sys.FileSystem.exists(".haxelib"))
		 	sys.FileSystem.createDirectory(".haxelib");*/

		// brief explanation: first we parse a json containing the library names, data, and such
		final libs:Array<Library> = cast haxe.Json.parse(sys.io.File.getContent("./hmm.json")).dependencies;

		// now we loop through the data we currently have
		for (data in libs)
		{
			// and install the libraries, based on their type
			switch (data.type)
			{
				case "install", "haxelib": // for libraries only available in the haxe package manager
					Sys.command('haxelib --quiet install ${data.name} ${data.version ?? ""}');
				case "git": // for libraries that contain git repositories
					Sys.command('haxelib --quiet git ${data.name} ${data.url} ${data.ref ?? ""}');
				default: // and finally, throw an error if the library has no type
					Sys.println('[PSYCH ENGINE SETUP]: Unable to resolve library of type "${data.type}" for library "${data.name}"');
			}
		}
		Sys.exit(0); // after the loop, we can leave
	}
}
