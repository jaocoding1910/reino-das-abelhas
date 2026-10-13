# Sons

Os 8 sons do jogo estão em `sons/` (arquivos `.wav`). Foram **gerados por código** (`sons/gerador/sons.py`), sem nenhum áudio de terceiros, então você pode usar e publicar à vontade.

| Arquivo | Quando toca |
|---|---|
| `Asas.wav` | zumbido em loop; fica mais alto e agudo quanto mais rápido você voa |
| `Coleta.wav` | ao coletar néctar ou favo |
| `Entrega.wav` | ao entregar no pote de mel |
| `Nivel.wav` | ao subir de nível, terminar pedido da Rainha e na recompensa diária |
| `Dano.wav` | ao levar dano |
| `Clique.wav` | ao clicar em qualquer botão |
| `AmbienteDia.wav` | música leve de dia (loop de 24 s) |
| `AmbienteNoite.wav` | grilos e acorde suave à noite (loop de 16 s) |

O jogo troca a música de dia e de noite sozinho, com transição suave.

## Ligar os sons (uma vez só)

O Roblox só toca áudio enviado para a plataforma. Então é preciso enviar os 8 arquivos e colar os números (IDs) no `Config.luau`.

1. No Studio, clique em **Ativos** (*Asset Manager*), na faixa de cima.
2. Clique em **Importar** (ícone de seta para cima) e selecione os 8 arquivos `.wav` da pasta `C:\Projetos Lua\reino-das-abelhas\sons`.
3. Confirme. Eles aparecem na pasta **Áudio** do gerenciador. O Roblox pode levar alguns minutos para aprovar.
4. Em cada áudio: botão direito → **Copiar ID do ativo**.
5. Cole o número em `src/shared/Config.luau`, dentro de `Config.Sounds`. Exemplo:

```lua
Config.Sounds = {
	Asas = "1234567890",
	Coleta = "1234567891",
	-- ...
}
```

6. Salve (o Rojo sincroniza) e aperte Play.

Pode colar só o número ou `rbxassetid://número`. O jogo aceita os dois. Som vazio fica em silêncio, sem erro.

**Limite:** contas do Roblox têm um limite mensal de envios de áudio (maior para contas com identidade verificada). São só 8 arquivos.

## Mudar os sons

Edite `sons/gerador/sons.py` (notas, duração, volume) e gere de novo:

```powershell
cd "C:\Projetos Lua\reino-das-abelhas\sons\gerador"
pip install numpy
python sons.py ..
```

Depois envie de novo os arquivos que mudaram e troque os IDs.
