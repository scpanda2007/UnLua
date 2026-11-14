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

## Project-owned UBT collector workaround

The collector refresh workaround is specific to the Plague host's custom build
tools. It belongs to `PlagueTests/Tools/Refresh-UbtPlugin.ps1`, not the generic
UnLua package. Use the PlagueTests installation guide for the optional pre-build
entry through `npv unrealcmd dotnet build`; unrealcmd resolves the host engine
and its bundled dotnet. No EngineDir argument or duplicate UE/SDK detection is
needed. NPV tool locations remain unchanged, with local EXEs reserved as a
fallback. This does not change the original automatic UBT/UHT exporter trigger
or automatically hook the workaround into packaging.

The UnLua change itself remains limited to writing Lua staging entries into the
opt-in custom INI. Target integration and old base-INI migration remain manual.

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
