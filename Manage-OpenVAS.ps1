# Launcher wrapper for the OpenVASWSLC orchestrator module
$LocalModulePath = Join-Path $PSScriptRoot "OpenVASWSLC"

if (Test-Path $LocalModulePath) {
    Import-Module $LocalModulePath -Force
} else {
    Import-Module OpenVASWSLC -Force
}

Manage-OpenVAS