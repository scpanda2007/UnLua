param(
    [Parameter(Mandatory = $true)][string]$EngineDir,
    [string]$PluginDir = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
$collectorEngineDir = (Resolve-Path -LiteralPath $EngineDir).ProviderPath
if (-not (Test-Path -LiteralPath (Join-Path $collectorEngineDir 'Build/Build.version'))) {
    $collectorEngineDir = (Resolve-Path -LiteralPath (Join-Path $collectorEngineDir 'Engine')).ProviderPath
}
$collectorVersion = Get-Content -LiteralPath (Join-Path $collectorEngineDir 'Build/Build.version') -Raw | ConvertFrom-Json
if ($collectorVersion.MajorVersion -ne 5 -or $collectorVersion.MinorVersion -ne 1 -or $collectorVersion.PatchVersion -ne 1) {
    throw 'This UE511 script requires Unreal Engine 5.1.1.'
}
$collectorPluginDir = (Resolve-Path -LiteralPath $PluginDir).ProviderPath
$collectorProject = Join-Path $collectorPluginDir 'Source/UnLuaDefaultParamCollectorUbtPlugin/UnLuaDefaultParamCollectorUbtPlugin.ubtplugin.csproj'
$collectorProject = (Resolve-Path -LiteralPath $collectorProject).ProviderPath
$collectorDotnet = (Resolve-Path -LiteralPath (Join-Path $collectorEngineDir 'Binaries/ThirdParty/DotNet/6.0.302/windows/dotnet.exe')).ProviderPath
$collectorToolSource = Join-Path $collectorEngineDir 'Source/GeneratedDlls/UnrealBuildTool'
$collectorToolDest = Join-Path $collectorEngineDir 'Binaries/DotNET/UnrealBuildTool'
$collectorProtectedHashes = @{}

# Deploy the designated tools before starting .NET; never copy back to the source.
foreach ($collectorName in @('EpicGames.UHT.dll', 'UnrealBuildTool.deps.json', 'UnrealBuildTool.dll')) {
    $collectorSourceFile = Join-Path $collectorToolSource $collectorName
    if (-not (Test-Path -LiteralPath $collectorSourceFile)) { continue }
    $collectorSourceHash = (Get-FileHash -LiteralPath $collectorSourceFile -Algorithm SHA256).Hash
    $collectorProtectedHashes[$collectorSourceFile] = $collectorSourceHash
    $collectorDestFile = Join-Path $collectorToolDest $collectorName
    if ((Test-Path -LiteralPath $collectorDestFile) -and
        (Get-FileHash -LiteralPath $collectorDestFile -Algorithm SHA256).Hash -eq $collectorSourceHash) { continue }
    Copy-Item -LiteralPath $collectorSourceFile -Destination $collectorDestFile -Force
}

# Build outside UBT so its in-process CsProjBuilder cannot copy over loaded tools.
$collectorStart = [Diagnostics.ProcessStartInfo]::new()
$collectorStart.FileName = $collectorDotnet
$collectorStart.WorkingDirectory = Split-Path $collectorProject -Parent
$collectorStart.UseShellExecute = $false
$collectorStart.Environment['DOTNET_ROOT'] = Split-Path $collectorDotnet -Parent
$collectorStart.Environment['DOTNET_MULTILEVEL_LOOKUP'] = '0'
$collectorStart.Environment['DOTNET_ROLL_FORWARD'] = 'Disable'
foreach ($collectorArg in @('build', $collectorProject, '--configuration', 'Development', '--nologo',
    "-p:EngineDir=$collectorEngineDir", '-p:BuildProjectReferences=false', '-p:UseSharedCompilation=false', '-nodeReuse:false')) {
    $collectorStart.ArgumentList.Add($collectorArg)
}
$collectorProcess = [Diagnostics.Process]::Start($collectorStart)
$collectorProcess.WaitForExit()
$collectorExit = $collectorProcess.ExitCode
$collectorProcess.Dispose()
foreach ($collectorSourceFile in $collectorProtectedHashes.Keys) {
    if ((Get-FileHash -LiteralPath $collectorSourceFile -Algorithm SHA256).Hash -ne $collectorProtectedHashes[$collectorSourceFile]) {
        throw "Designated tool source changed: $collectorSourceFile"
    }
}
if ($collectorExit -ne 0) { throw "UnLua UBT collector build failed: $collectorExit" }
Write-Output 'UnLua UBT collector refreshed. Continue with the normal Editor target build.'
