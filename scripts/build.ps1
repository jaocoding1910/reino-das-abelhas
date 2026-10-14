# Gera o place a partir do código (sem os modelos 3D, que ficam no seu place
# ou em assets/PacoteAbelhas.rbxm) e confere o código.
# Uso (PowerShell, na pasta do projeto):  .\scripts\build.ps1
$ErrorActionPreference = "Stop"
$env:Path += ";$env:USERPROFILE\.rokit\bin"
Set-Location (Split-Path $PSScriptRoot -Parent)

rokit install
stylua --check src
if ($LASTEXITCODE -ne 0) { Write-Host "StyLua: rode 'stylua src' para formatar." -ForegroundColor Yellow }
New-Item -ItemType Directory -Force build | Out-Null
rojo build default.project.json -o build\ReinoDasAbelhas_codigo.rbxlx
Write-Host "Place gerado: build\ReinoDasAbelhas_codigo.rbxlx" -ForegroundColor Green
Write-Host "Para jogar com sincronização: rojo serve (porta 34872) e Connect no plugin do Rojo." -ForegroundColor Green
