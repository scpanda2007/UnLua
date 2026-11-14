# Lua script packaging through CustomConfig

UnLuaEditor generates `Config/Custom/UnLua/DefaultGame.ini` in the host project.
It appends missing `+DirectoriesToAlwaysStageAsUFS` entries for the project's
`Content/Script`, the installed UnLua plugin's `Content/Script`, and enabled
UnLuaExtensions script directories. Plugin paths are relative to the project's
Content directory, so the UnLua installation need not be at `Plugins/UnLua`.

This changes only the custom file. It does not mutate the packaging settings CDO,
write the base `Config/DefaultGame.ini`, or select a CustomConfig for the process.
Existing custom text/settings are preserved, repeated execution does not add the
same generated entry again, and read/write failures are logged.

The host owns the build policy in its game Target.cs. For this project's policy,
non-Shipping builds select `CustomConfig = "UnLua"` and retain the test/Lua plugin
suite. Shipping omits that custom layer and uses `DisablePlugins` to remove the
entire suite. Disabling dependent test/adapter plugins belongs to the same Target
policy. No Target.cs is changed by the plugin.

If the host already uses another CustomConfig name, integrate these settings with
that profile explicitly rather than overwriting its Target setting. The generated
file alone does not enable packaging: build the matching Editor module and let it
generate the file before cooking with the selected profile.

Old entries previously written to the base DefaultGame.ini are not automatically
removed. Review and migrate those specific entries separately; they can otherwise
continue to stage Lua files in Shipping even without the custom layer. This
migration does not remove existing project settings or claim a verified Shipping
package. No Shipping package verification is claimed. Validation facts are recorded below.

## UE511 collector refresh before building Editor

From the host project, with PowerShell 7:

```powershell
pwsh -NoProfile -File .\Plugins\UnLua\Tools\Refresh-UbtPlugin.ps1 -EngineDir 'D:\Home_Plague\Engine\Engine'
```

Use the actual plugin installation path. The script resolves the engine-bundled
.NET 6.0.302 and builds the UBT collector outside UBT before the normal Editor
build. It deploys the three designated GeneratedDlls tools to Binaries before
starting .NET, skips identical files, and verifies the designated source hashes
are unchanged. It does not rename engine directories, patch engine source, kill
processes, fabricate build records, or disable default-parameter collection.

The host Target integration and old base-INI migration are manual steps. Updating
the plugin does not enable a custom layer or remove existing project settings.

## Validation for 5.1.1-rdo.2

On the custom UE5.1.1 host, the refresh script completed with 0 warnings/errors.
A subsequent coordinated build of UnLuaEditor and the four consuming Feature/
project modules returned 0, without changing the three designated tool-source
hashes. The first normal build had reproduced the in-process UHT DLL copy lock.

In an isolated minimal host, startup generated both required script entries in
the custom layer, preserved existing comments/settings/paths and left the base
DefaultGame.ini unchanged. A repeated startup left the custom file byte-identical.
The first harness attempt used the game `quit` command and timed out; the
corrected Editor close command reached a GenericWindow.cpp fatal under NullRHI
and returned native exit code 3. These process outcomes are retained separately
from the successful configuration-write checks. Clean Editor shutdown, an actual
Shipping package exclusion, and packaged Plague Runtime behavior are unverified.
