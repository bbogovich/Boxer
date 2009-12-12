/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXPackage.h"
#import "NSString+BXPaths.h"
#import "NSWorkspace+BXFileTypes.h"
#import "IconFamily+BXIconFamily.h"

@implementation BXPackage
@synthesize documentation, executables;

+ (NSArray *) hddVolumeTypes
{
	return [NSArray arrayWithObjects:
		@"net.washboardabs.boxer-harddisk-folder",
	nil];
}

+ (NSArray *) cdVolumeTypes
{
	return [NSArray arrayWithObjects:
		@"com.goldenhawk.cdrwin-cuesheet",
		@"net.washboardabs.boxer-cdrom-folder",
		@"public.iso-image",
		@"com.apple.disk-image-cdr",
		@"com.gog.gog-disk-image",
	nil];
}

+ (NSArray *) floppyVolumeTypes
{
	return [NSArray arrayWithObjects:
		@"net.washboardabs.boxer-floppy-folder",
	nil];
}


+ (NSArray *) documentationTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
		@"public.jpeg",
		@"public.plain-text",
		@"public.png",
		@"com.compuserve.gif",
		@"com.adobe.pdf",
		@"public.rtf",
		@"com.microsoft.bmp",
		@"com.microsoft.word.doc",
		@"public.html",
	nil];
	return types;
}

//We ignore files with these names when considering which documentation files are likely to be worth showing
//TODO: read this data from a configuration plist instead
+ (NSArray *) documentationExclusions
{
	static NSArray *exclusions = nil;
	if (!exclusions) exclusions = [[NSArray alloc] initWithObjects:
		@"install.gif",
		@"install.txt",
		@"interp.txt",
		@"order.txt",
		@"orderfrm.txt",
		@"license.txt",
	nil];
	return exclusions;
}

+ (NSArray *) executableTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
		@"com.microsoft.windows-executable",	//.exe
		@"com.microsoft.msdos-executable",		//.com
		@"com.microsoft.batch-file",			//.bat
	nil];
	return types;
}

//We ignore files with these names when considering which programs are important enough to list
//TODO: read this data from a configuration plist instead
+ (NSArray *) executableExclusions
{
	static NSArray *exclusions = nil;
	if (!exclusions) exclusions = [[NSArray alloc] initWithObjects:
		@"dos4gw.exe",
		@"pkunzip.exe",
		@"lha.com",
		@"arj.exe",
		@"deice.exe",
		@"pkunzjr.exe",
	nil];
	return exclusions;
}


- (void) dealloc
{
	[self setDocumentation: nil],	[documentation release];
	[self setExecutables: nil],		[executables release];
	[super dealloc];
}


- (NSArray *) hddVolumes	{ return [self volumesOfTypes: [[self class] hddVolumeTypes]]; }
- (NSArray *) cdVolumes		{ return [self volumesOfTypes: [[self class] cdVolumeTypes]]; }
- (NSArray *) floppyVolumes	{ return [self volumesOfTypes: [[self class] floppyVolumeTypes]]; }

- (NSArray *) volumesOfTypes: (NSArray *)acceptedTypes
{
	NSMutableArray *volumes	= [NSMutableArray arrayWithCapacity: 10];
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSString *basePath		= [self resourcePath];
	
	NSString *fileName, *filePath, *fileType;
	for (fileName in [manager contentsOfDirectoryAtPath: basePath error: nil])
	{
		filePath	= [basePath stringByAppendingPathComponent: fileName];
		if ([workspace file: filePath matchesTypes: acceptedTypes]) [volumes addObject: filePath];
	}
	return volumes;
}

- (NSString *) configurationPath	{ return [self pathForResource: @"DOSBox Preferences" ofType: @"conf"]; }
- (NSString *) gamePath				{ return [self bundlePath]; }

- (NSString *) targetPath
{
	NSString *symlinkPath	= [self pathForResource: @"DOSBox Target" ofType: nil];
	NSString *targetPath	= [symlinkPath stringByResolvingSymlinksInPath];
	
	//If the path is unchanged, this indicates a broken link
	if ([targetPath isEqualToString: symlinkPath]) targetPath = nil;
	
	return targetPath;
}

- (void) setTargetPath: (NSString *)path
{
	[self willChangeValueForKey: @"targetPath"];
	
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSString *linkLocation	= [[self resourcePath] stringByAppendingPathComponent: @"DOSBox Target"];
	
	//Todo: handle errors better (at all)!
	
	//First, attempt to delete any existing link
	[manager removeItemAtPath: linkLocation error: nil];
	
	//If a new path was specified, create a new link
	if (path)
	{
		//Make the link relative to the game package
		NSString *basePath		= [self resourcePath];
		NSString *relativePath	= [path pathRelativeToPath: basePath];
	
		[manager createSymbolicLinkAtPath: linkLocation withDestinationPath: relativePath error: nil];
	}
	
	[self didChangeValueForKey: @"targetPath"];
}

//Set/return the cover art associated with this game package (currently, the package file's icon)
- (NSImage *) coverArt
{
	if ([IconFamily fileHasCustomIcon: [self bundlePath]])
	{
		return [[NSWorkspace sharedWorkspace] iconForFile: [self bundlePath]];
	}
	else return nil;
}

- (void) setCoverArt: (NSImage *)image
{
	[self willChangeValueForKey: @"coverArt"];
	
	if (image)
	{
		IconFamily *icon = [IconFamily iconFamilyWithRepresentationsFromImage: image];
		[icon setAsCustomIconForDirectory: [self bundlePath]];
	}
	else
	{
		//Delete the custom icon altogether
		[[NSWorkspace sharedWorkspace] setIcon: nil forFile: [self bundlePath] options: 0];
	}

	[self didChangeValueForKey: @"coverArt"];
}

//Lazily discover and cache executables the first time we need them
- (NSArray *) executables
{
	if (executables == nil) [self setExecutables: [self _foundExecutables]];
	return executables;
}

//Lazily discover and cache documentation the first time we need it
- (NSArray *) documentation
{
	if (documentation == nil) [self setDocumentation: [self _foundDocumentation]];
	return documentation;
}

@end


//Methods in this category are not intended to be called outside of BXPackage.
@implementation BXPackage (BXPackageInternals)

//Trawl the package looking for DOS executables
//TODO: check these against file() to weed out non-DOS exes
- (NSArray *) _foundExecutables
{
	NSArray *foundExecutables	= [self _foundResourcesOfTypes: [[self class] executableTypes] startingIn: [self gamePath]];
	NSPredicate *notExcluded	= [NSPredicate predicateWithFormat: @"NOT lastPathComponent.lowercaseString IN %@", [[self class] executableExclusions]];

	return [foundExecutables filteredArrayUsingPredicate: notExcluded];
}

- (NSArray *) _foundDocumentation
{
	//First, check if there is an explicitly-named documentation folder and use the contents of that if so
	NSArray *docsFolderContents = [self pathsForResourcesOfType: nil inDirectory: @"Documentation"];
	if ([docsFolderContents count]) return docsFolderContents;

	//Otherwise, go trawling through the entire game package looking for likely documentation
	NSArray *foundDocumentation	= [self _foundResourcesOfTypes: [[self class] documentationTypes] startingIn: [self gamePath]];
	NSPredicate *notExcluded	= [NSPredicate predicateWithFormat: @"NOT lastPathComponent.lowercaseString IN %@", [[self class] documentationExclusions]];

	return [foundDocumentation filteredArrayUsingPredicate: notExcluded];
}

- (NSArray *) _foundResourcesOfTypes: (NSArray *)fileTypes startingIn: (NSString *)basePath
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSFileManager *manager	= [NSFileManager defaultManager];
	NSMutableArray *matches	= [NSMutableArray arrayWithCapacity: 10];
	
	for (NSString *fileName in [manager enumeratorAtPath: basePath])
	{
		NSString *filePath = [basePath stringByAppendingPathComponent: fileName];
		
		//Note that we don't use our own smarter file:matchesTypes: function for this,
		//because there are some inherited filetypes that we want to avoid matching.
		if ([fileTypes containsObject: [workspace typeOfFile: filePath error: nil]]) [matches addObject: filePath];
	}
	return matches;	
}
@end