namespace FifaStreetSetupTool;

internal static class InstallationUpdate
{
    internal static bool IsInstallation(string root) =>
        File.Exists(Path.Combine(root, "Game", "fifastreet.exe")) &&
        File.Exists(Path.Combine(root, "GameData", "default.xex"));

    // What the ReStreet online patch (v1.1-online-N) adds to an installation, apart from files the payload replaces.
    static readonly string[] OnlineLeftovers =
    {
        "online.json", "Game/online.json", "online-patch.json", "tools/ReStreetAssetExplorer.exe",
    };

    internal static void Apply(string bundle, string root)
    {
        root = Path.GetFullPath(root);
        if (!IsInstallation(root)) throw new IOException("Select the existing installation folder containing Game and GameData.");
        Console.WriteLine("Checking the installed game version and update files...");
        var package = PrecompiledPackage.Validate(bundle, Path.Combine(root, "GameData"));
        var files = package.Payload.Keys.Where(name => !name.Equals("Game/fifastreet.toml", StringComparison.OrdinalIgnoreCase) || !File.Exists(Path.Combine(root, name))).ToArray();
        // Validate all paths and locks before changing any installed file.
        foreach (string name in files)
        {
            string target = Path.GetFullPath(Path.Combine(root, name));
            for (var folder = new DirectoryInfo(Path.GetDirectoryName(target)!); folder != null; folder = folder.Parent)
            {
                if (folder.Exists && (folder.Attributes & FileAttributes.ReparsePoint) != 0)
                    throw new IOException("Updates cannot follow linked installation folders.");
            }
            if (File.Exists(target))
            {
                if ((File.GetAttributes(target) & FileAttributes.ReparsePoint) != 0) throw new IOException("Updates cannot replace linked files.");
                using var locked = new FileStream(target, FileMode.Open, FileAccess.ReadWrite, FileShare.None);
            }
        }
        string backupRoot = Path.Combine(root, ".updates");
        if (Directory.Exists(backupRoot) && (File.GetAttributes(backupRoot) & FileAttributes.ReparsePoint) != 0)
            throw new IOException("Updates cannot use a linked backup folder.");
        string backup = Path.Combine(backupRoot, DateTime.UtcNow.ToString("yyyyMMdd-HHmmss") + "-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(backup);
        var touched = new List<(string Target, string? Saved)>();
        try
        {
            Console.WriteLine("Installing update. Saves, game data and preferences are preserved...");
            foreach (string name in files)
            {
                InstallerEngine.CancellationToken.ThrowIfCancellationRequested();
                string target = Path.Combine(root, name), saved = Path.Combine(backup, name);
                bool existed = File.Exists(target);
                if (existed)
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(saved)!);
                    File.Copy(target, saved);
                }
                touched.Add((target, existed ? saved : null));
                Directory.CreateDirectory(Path.GetDirectoryName(target)!);
                File.Copy(Path.Combine(bundle, "payload", name), target, true);
                Console.WriteLine("Updated " + name);
            }
            // The online patch replaced files that the payload above has just overwritten; what is left is what it added.
            foreach (string name in OnlineLeftovers)
            {
                string target = Path.Combine(root, name), saved = Path.Combine(backup, name);
                if (!File.Exists(target)) continue;
                if ((File.GetAttributes(target) & FileAttributes.ReparsePoint) != 0) throw new IOException("Updates cannot remove linked files.");
                Directory.CreateDirectory(Path.GetDirectoryName(saved)!);
                File.Copy(target, saved);
                touched.Add((target, saved));
                File.Delete(target);
                Console.WriteLine("Removed online file " + name);
            }
            string toolsFolder = Path.Combine(root, "tools");
            if (Directory.Exists(toolsFolder) && !Directory.EnumerateFileSystemEntries(toolsFolder).Any()) Directory.Delete(toolsFolder);
            InstallerEngine.CancellationToken.ThrowIfCancellationRequested();
            File.WriteAllText(Path.Combine(backup, "update-complete.txt"), "Previous binaries retained. GameData and user preferences were not modified.");
            // Only the online patch's saved copies of the old offline files: v1.2 replaces them, so they are not kept.
            string onlineBackup = Path.Combine(root, "OnlinePatch");
            if (Directory.Exists(onlineBackup) && (File.GetAttributes(onlineBackup) & FileAttributes.ReparsePoint) == 0)
            {
                try { Directory.Delete(onlineBackup, true); Console.WriteLine("Removed the online patch backup folder."); }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException) { Console.WriteLine("Could not remove OnlinePatch (delete it by hand): " + error.Message); }
            }
            // Stadium pictures the online launcher generated with the asset tool; the offline launcher never uses them.
            string thumbs = Path.Combine(root, "Game", "stadium-thumbs");
            if (Directory.Exists(thumbs) && (File.GetAttributes(thumbs) & FileAttributes.ReparsePoint) == 0)
            {
                try { Directory.Delete(thumbs, true); Console.WriteLine("Removed the online stadium pictures."); }
                catch (Exception error) when (error is IOException or UnauthorizedAccessException) { Console.WriteLine("Could not remove Game\\stadium-thumbs (delete it by hand): " + error.Message); }
            }
            Console.WriteLine("Update complete. Previous files saved at: " + backup);
        }
        catch (Exception original)
        {
            // Roll back without consulting cancellation: restoration must finish.
            var failures = new List<Exception>();
            foreach (var file in touched.AsEnumerable().Reverse())
                try
                {
                    if (file.Saved != null) File.Copy(file.Saved, file.Target, true);
                    else if (File.Exists(file.Target)) File.Delete(file.Target);
                }
                catch (Exception error) { failures.Add(error); }
            if (failures.Count != 0)
                throw new IOException("The update failed and some files could not be restored. Keep the backup at: " + backup,
                    new AggregateException(new[] { original }.Concat(failures)));
            Console.WriteLine("Update stopped. Previous files restored.");
            throw;
        }
    }
}
