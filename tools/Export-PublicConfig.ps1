#requires -Version 7.3
[CmdletBinding()]
param(
    [string]$DshRoot = (Join-Path $env:USERPROFILE 'Documents/Codex/.dsh'),
    [string]$DeepTutorData = 'E:\DeepTutorData',
    [string]$JetBrainsInstall = $(if(Test-Path -LiteralPath 'D:/Program Files/JetBrains'){'D:/Program Files/JetBrains'}else{Join-Path $env:ProgramFiles 'JetBrains'}),
    [string]$VsExtensions = (Join-Path $env:USERPROFILE '.vscode/extensions')
)
$ErrorActionPreference = 'Stop'
function Read-JsonFile([string]$Path) {
    Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
}
function Select-PublicValue($Value, [string[]]$Allowed) {
    if ($null -eq $Value) { return 'unset' }
    if ([string]$Value -cin $Allowed) { return [string]$Value }
    return 'not-in-public-list'
}
function Get-PublicVersion([string]$Value) {
    if ($Value -match '(?<!\d)\d+(?:\.\d+){0,4}(?!\d)') { return $Matches[0] }
    return 'unknown'
}
$publicModels = @('gpt-6.2-sol','gpt-6.2-astra','deepseek-flash','deepseek-v4-pro',
    'ccs-claude-github--gpt-4.1[1m]','ccs-claude-deepseek--deepseek-v4-pro[1m]',
    'qwen3:8b','qwen3-embedding:4b','edge-tts','gpt-image-2.6-sunburst')
$efforts = @('off','none','minimal','low','medium','high','xhigh','max','ultra')
$ai = [ordered]@{}
$cc = Read-JsonFile (Join-Path $env:USERPROFILE '.claude/settings.json')
$roles = [ordered]@{}
foreach ($role in 'HAIKU','SONNET','OPUS','FABLE') {
    $roles[$role] = Select-PublicValue $cc.env["ANTHROPIC_DEFAULT_${role}_MODEL"] $publicModels
}
$ai.claudeCode = [ordered]@{model=Select-PublicValue $cc.model $publicModels; aliases=$roles}
# Python's standard TOML parser respects tables, comments and quoted strings.
$tomlReader = 'import json,pathlib,tomllib; d=tomllib.loads((pathlib.Path.home()/".codex"/"config.toml").read_text(encoding="utf-8-sig")); print(json.dumps({k:d.get(k) for k in ("model","model_reasoning_effort","service_tier")}))'
$codexJson = & python -c $tomlReader
if ($LASTEXITCODE -ne 0) { throw 'Codex TOML requires Python 3.11+.' }
$cx = $codexJson | ConvertFrom-Json -AsHashtable
$ai.codex = [ordered]@{model=Select-PublicValue $cx.model $publicModels; reasoningEffort=Select-PublicValue $cx.model_reasoning_effort $efforts; serviceTier=Select-PublicValue $cx.service_tier @('default','fast','flex','priority')}
$yaml = Get-Content -LiteralPath (Join-Path $DshRoot 'profiles/web/cordis.patch.yml') -Encoding utf8
$entry = $false
$conf = $false
$dsh = @{}
foreach ($line in $yaml) {
    if ($line -match '^-\s+') { $entry = $line -match '^-\s+id:\s*agent-default-model\s*$'; $conf=$false }
    elseif ($entry -and $line -match '^  \S') { $conf = $line -match '^  config:\s*$' }
    elseif ($entry -and $conf -and $line -match '^    (model|provider|reasoningEffort):\s*["'']?([\w./-]+)["'']?\s*$') { $dsh[$Matches[1]]=$Matches[2] }
}
if (!$dsh.ContainsKey('model')) { throw 'Unrecognized DSH default model format; previous snapshot retained.' }
$ai.dsh = [ordered]@{model=Select-PublicValue $dsh.model $publicModels;provider=Select-PublicValue $dsh.provider @('deepseek-official','openai','anthropic','ollama'); reasoningEffort=Select-PublicValue $dsh.reasoningEffort $efforts}
$catalog = Read-JsonFile (Join-Path $DeepTutorData 'data/user/settings/model_catalog.json')
if (!$catalog.services) { throw 'DeepTutor service catalog missing.' }
$dt = [ordered]@{}
foreach ($slot in 'llm','task','embedding','search','tts','stt','imagegen','videogen') {
    $service=$catalog.services[$slot]
    $profile=$service.profiles | Where-Object { $_.id -eq $service.active_profile_id } | Select-Object -First 1
    $model=$profile.models | Where-Object { $_.id -eq $service.active_model_id } | Select-Object -First 1
    $dt[$slot]=[ordered]@{activeProfile=[bool]$service.active_profile_id;model=Select-PublicValue $model.model $publicModels}
    if ($slot -eq 'search') {$dt[$slot].provider=Select-PublicValue $profile.provider @('firecrawl','duckduckgo','tavily','searxng','brave','bing')}
}
$ai.deepTutor=$dt
$ides = [ordered]@{}
$actions = @('$Redo','ActivateBookmarksToolWindow','ClaudeCodeGUI.ChatNewlineAction','EditorDeleteLine','RunAnything','DatabaseView.PropertiesAction')
foreach ($product in 'CLion','PyCharm','IntelliJIdea') {
    $folders=Get-ChildItem -LiteralPath (Join-Path $env:APPDATA 'JetBrains') -Directory |
        Where-Object { $_.Name -match "^$product(\d{4}\.\d+(?:\.\d+)*)$" -and (Test-Path -LiteralPath (Join-Path $_.FullName 'options')) } |
        Sort-Object { [version]($_.Name.Substring($product.Length)) } -Descending
    $folder=$folders | Select-Object -First 1
    if (!$folder) { throw "No configuration found for $product." }
    $maps = @(foreach ($file in Get-ChildItem -Path (Join-Path $folder.FullName 'keymaps/*.xml') -File -ErrorAction SilentlyContinue | Sort-Object Name) {
        $xml=[xml](Get-Content -LiteralPath $file.FullName -Raw)
        $bindings=[ordered]@{}
        foreach ($action in $xml.keymap.action) {
            if ($action.id -cnotin $actions) {continue}
            $bindings[$action.id]=@(foreach($shortcut in $action.'keyboard-shortcut'){
                if (!$shortcut) {continue}
                $first=[string]$shortcut.'first-keystroke'
                $second=[string]$shortcut.'second-keystroke'
                if ($first -match '^[a-zA-Z0-9_ ]{1,60}$' -and $second -match '^[a-zA-Z0-9_ ]{0,60}$') {
                    [ordered]@{first=$first;second=$second}
                }
            })
        }
        [ordered]@{parent=Select-PublicValue $xml.keymap.parent @('$default','Mac OS X','Windows','Visual Studio','Eclipse');bindings=$bindings}
    })
    $sdkFile=Join-Path $folder.FullName 'options/jdk.table.xml'
    $sdks=@(if(Test-Path -LiteralPath $sdkFile){
        $xml=[xml](Get-Content -LiteralPath $sdkFile -Raw)
        foreach($sdk in $xml.application.component.jdk){
            [ordered]@{type=Select-PublicValue $sdk.type.value @('JavaSDK','Python SDK');version=Get-PublicVersion $sdk.version.value}
        }
    })
    $ides[$product]=[ordered]@{configVersion=$folder.Name.Substring($product.Length);registeredSDKs=$sdks;customKeymaps=$maps}
}
if(Test-Path -LiteralPath $JetBrainsInstall){
    $clion=Get-ChildItem -LiteralPath $JetBrainsInstall -Directory | Where-Object Name -Match '^CLion \d+(\.\d+)+$' |
        Sort-Object { [version](($_.Name -split ' ')[1]) } -Descending | Select-Object -First 1
    if($clion){$ides.CLion.bundledToolDirectories=@('cmake','ninja','mingw','clang','gdb','lldb' | Where-Object {Test-Path -LiteralPath (Join-Path $clion.FullName "bin/$_")})}
}
function Select-EditorSettings($Settings) {
    $selected=[ordered]@{}
    foreach($key in 'editor.fontSize','editor.tabSize','editor.formatOnSave','editor.wordWrap','files.autoSave'){
        if (!$Settings.Contains($key)) {continue}
        $val=$Settings[$key]
        if ($val -is [bool] -or ($val -is [long] -and $val -ge 0 -and $val -le 256) -or
            $val -cin @('on','off','bounded','wordWrapColumn','afterDelay','onFocusChange','onWindowChange')) {$selected[$key]=$val}
    }
    return $selected
}
$userDir=Join-Path $env:APPDATA 'Code/User'
$profiles=@((Get-Item -LiteralPath $userDir)) + @(Get-ChildItem -Path (Join-Path $userDir 'profiles/*') -Directory -ErrorAction SilentlyContinue | Sort-Object Name)
$settings=@(foreach($profile in $profiles){
    $file=Join-Path $profile.FullName 'settings.json'
    $item=[ordered]@{scope=if($profile.FullName -eq $userDir){'default'}else{'named'}; hasSettings=(Test-Path -LiteralPath $file)}
    if($item.hasSettings){
        $source=Read-JsonFile $file
        $item.settings=Select-EditorSettings $source
        foreach($lang in '[markdown]','[python]','[cpp]','[java]','[bat]'){
            if($source[$lang] -is [System.Collections.IDictionary]){$item.settings[$lang]=Select-EditorSettings $source[$lang]}
        }
    }
    $item
})
$extFile=Join-Path $VsExtensions 'extensions.json'
$extensions=@(if(Test-Path -LiteralPath $extFile){
    foreach($ext in (Read-JsonFile $extFile) | Sort-Object { $_.identifier.id }){
        if($ext.identifier.id -cin @('ms-python.python','ms-python.debugpy','ms-python.vscode-pylance','ms-vscode.cpptools','ms-vscode.cmake-tools','redhat.java','vscjava.vscode-java-pack','vscjava.vscode-java-debug','github.copilot','github.copilot-chat')){
            [ordered]@{id=$ext.identifier.id;version=Get-PublicVersion $ext.version}
        }
    }
})
$ides.vscode=[ordered]@{profiles=$settings;extensionRegistryPresent=(Test-Path -LiteralPath $extFile);selectedExtensions=$extensions}
$result=[ordered]@{schemaVersion=1;platform='Windows';agents=$ai;ides=$ides}
$target=Join-Path $PSScriptRoot '../snapshots/windows.json'
$json=($result | ConvertTo-Json -Depth 16) + [Environment]::NewLine
$tempFile=Join-Path (Split-Path $target) ('.snapshot-' + [guid]::NewGuid() + '.tmp')
[IO.File]::WriteAllText($tempFile,$json,[Text.UTF8Encoding]::new($false))
[IO.File]::Move($tempFile,$target,$true)
