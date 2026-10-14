# Extrai o zip mais novo de Downloads por cima do projeto, sem apagar nada seu
# (o seu ReinoDasAbelhas.rbxlx e a pasta assets/ não vêm no zip).
# Uso:  & "C:\Projetos Lua\reino-das-abelhas\scripts\atualizar.ps1"
$zip = Get-ChildItem "$env:USERPROFILE\Downloads\reino-das-abelhas*.zip" |
	Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $zip) { Write-Host "Nenhum reino-das-abelhas*.zip em Downloads." -ForegroundColor Red; exit 1 }
Write-Host "Usando $($zip.FullName)"
Expand-Archive -Path $zip.FullName -DestinationPath "C:\Projetos Lua" -Force
Select-String -Path "C:\Projetos Lua\reino-das-abelhas\src\shared\Types.luau" -Pattern "PROFILE_VERSION ="
