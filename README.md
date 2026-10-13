# Reino das Abelhas 🐝

Jogo para Roblox em Luau. O código é editado no **VS Code** e sincronizado com o **Roblox Studio** pelo **Rojo**.

> **Estado atual:** jogo completo para teste, agora com voo inclinando nas curvas, arrancada, missões em sequência, mel fabricado pela colmeia, especialidades, painel com abas, animações de coleta/nível, pólen e vaga-lumes, e um pacote de modelos 3D próprios (`modelos3d/`). Inclui: voo, mapa com árvores-colmeia, flores gigantes, bosque e Colmeia Real; três raridades de favo; colmeia que cresce; melhorias e acessórios; dia e noite; aranhas; vida, derrota e carga perdida; combate na zona de disputa; nível/XP; salvamento. Veja `docs/ROADMAP.md` (roteiro de teste) e `docs/MODELOS_3D.md` (deixar com cara das imagens de referência).

**Controles (PC):** WASD voa · Espaço sobe · Ctrl/Q desce · **Shift arranca** (gasta fôlego) · **G** liga/desliga a trilha dourada até o objetivo · segure E para coletar/entregar/construir · clique ataca (zona de disputa) · 1 Coletar · 2 Sua colmeia (ou U) · 3 Clã · Esc solta o mouse.
**Celular:** joystick + botões Subir/Descer/Arrancar/Atacar · toque nos avisos e na barra de ações.

---

## 1. Estrutura de pastas

```
reino-das-abelhas/
├── default.project.json      ← mapa do Rojo: pasta do PC → lugar no Roblox
├── rokit.toml                ← versões fixas das ferramentas (Rojo, Selene, StyLua)
├── selene.toml               ← regras do verificador de código
├── stylua.toml               ← regras do formatador
├── .vscode/                  ← extensões recomendadas, configurações e tarefas
├── assets/                   ← modelos .rbxm exportados do Studio (vira ReplicatedStorage.Assets)
├── modelos3d/                ← PacoteAbelhas.glb (importar no Studio) + gerador em Python
├── docs/
│   ├── ARQUITETURA.md        ← como o código conversa e as regras de segurança
│   ├── MODELOS_3D.md         ← importar o pacote de modelos 3D
│   └── ROADMAP.md            ← etapas A–E e o que falta
└── src/
    ├── shared/               → ReplicatedStorage.Shared   (servidor e cliente leem)
    │   ├── Config.luau       ← TODO o balanceamento do jogo
    │   ├── Remotes.luau      ← lista de canais cliente ↔ servidor
    │   ├── Types.luau        ← formato do perfil salvo e da carga
    │   └── Util/             ← Loader (Init/Start) e Log
    ├── server/               → ServerScriptService.Server  (só o servidor)
    │   ├── init.server.luau  ← bootstrap: ordem dos serviços
    │   ├── Services/         ← um arquivo por sistema (coleta, colmeia, combate…)
    │   ├── Predators/        ← PredatorBase (contrato) + Spider
    │   └── World/            ← MapBuilder (cenário por código)
    └── client/               → StarterPlayer.StarterPlayerScripts.Client
        ├── init.client.luau  ← bootstrap do cliente
        ├── Controllers/      ← entrada, voo, câmera, interação, HUD, áudio
        └── UI/               ← Theme (cores douradas, fontes) e Widgets (hexágonos, barras)
```

**Regra dos nomes de arquivo (Rojo):**

| Arquivo | Vira no Roblox |
|---|---|
| `Nome.luau` | ModuleScript |
| `Nome.server.luau` | Script (servidor) |
| `Nome.client.luau` | LocalScript (cliente) |
| `init.server.luau` dentro de uma pasta | a própria pasta vira Script, com os arquivos dentro como filhos |

---

## 2. Instalação (Windows, uma vez só)

Use o **PowerShell**. Precisa de: VS Code, Roblox Studio e Git instalados.

### 2.1 Coloque o projeto numa pasta simples

Extraia o zip em `C:\Projetos\reino-das-abelhas`. Evite pastas do OneDrive (Documentos/Área de Trabalho sincronizados), que travam arquivos durante a sincronização.

### 2.2 Instale o Rokit (gerenciador das ferramentas)

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```

**Feche e abra o PowerShell de novo** e confira:

```powershell
rokit --version
```

> Se der erro de "execução de scripts desabilitada", rode antes:
> `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` e responda `S`.

### 2.3 Instale as ferramentas do projeto

```powershell
cd C:\Projetos\reino-das-abelhas
rokit install
```

Quando perguntar se confia nas ferramentas, responda `y`. Depois confira:

```powershell
rojo --version     # deve mostrar Rojo 7.7.1
```

### 2.4 Abra no VS Code e instale as extensões

```powershell
code .
```

O VS Code vai sugerir as extensões recomendadas. Clique em **Instalar todas**:

- **Rojo** (evaera.vscode-rojo)
- **Luau Language Server** (JohnnyMorganz.luau-lsp) — autocompletar e erros de tipo
- **Selene** (Kampfkarren.selene-vscode) — aponta código suspeito
- **StyLua** (JohnnyMorganz.stylua) — formata ao salvar

### 2.5 Instale o plugin do Rojo no Roblox Studio

Com o **Studio fechado**:

```powershell
rojo plugin install
```

(Alternativa: no Studio, Toolbox → Plugins → procure "Rojo" do autor oficial.)

---

## 3. Primeira execução

### 3.1 Gere o place

```powershell
rojo build -o ReinoDasAbelhas.rbxlx
```

Dê dois cliques em `ReinoDasAbelhas.rbxlx` (ou Studio → File → Open). Esse é o seu arquivo de trabalho: salve com **Ctrl+S** normalmente.

### 3.2 Ligue a sincronização

No PowerShell (na pasta do projeto):

```powershell
rojo serve
```

Ou no VS Code: **Ctrl+Shift+B** (tarefa "Rojo: iniciar sincronização"). Deixe rodando.

### 3.3 Conecte o Studio

No Studio: aba **Plugins → Rojo → Connect** (endereço `localhost`, porta `34872`). Deve aparecer "Connected".

### 3.4 Teste

Aperte **Play (F5)**. Na janela **Output** (View → Output) devem aparecer:

```
[Abelhas:Servidor] 12 módulos iniciados
[Abelhas:Cliente] 6 módulos iniciados
```

Agora edite qualquer arquivo em `src/` no VS Code e salve: a mudança aparece no Studio na hora.

**Dois jogadores:** aba **Test → Clients and Servers → 2 Players → Start**.
**Celular:** aba **Test → Device** e escolha um celular para ver a interface.

---

## 4. Rotina de trabalho

1. Abra o VS Code na pasta e rode `rojo serve` (Ctrl+Shift+B).
2. Abra `ReinoDasAbelhas.rbxlx` no Studio e clique em **Connect**.
3. Programe no VS Code. Teste no Studio com Play.
4. Ao terminar: salve o place (Ctrl+S) e faça commit no Git.

### Regras de ouro

- **Código só no VS Code.** Mudanças feitas no Studio em scripts sincronizados são sobrescritas pelo Rojo.
- **Cenário e modelos no Studio.** O Rojo só controla o que está no `default.project.json`. O Workspace (mapa montado à mão) fica salvo no `.rbxlx`.
- **Modelo pronto vira arquivo.** Clique com o direito no modelo → *Save to File* → salve em `assets/` como `.rbxm`. Ele aparece em `ReplicatedStorage.Assets` e passa a ser versionado no Git.
- **Balanceamento só no `Config.luau`.** Nenhum número de jogo espalhado pelo código.

---

## 5. Salvamento (DataStore)

Para o `PlayerDataService` salvar dados no Studio:

1. **File → Publish to Roblox** (crie a experiência).
2. **Game Settings → Security → Enable Studio Access to API Services** → ligar.

---

## 6. Git e GitHub

```powershell
git init
git add .
git commit -m "Estrutura inicial do Reino das Abelhas com Rojo"
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/reino-das-abelhas.git
git push -u origin main
```

O `.gitignore` já deixa de fora o place (`.rbxlx`) e arquivos gerados. O que importa — código, configuração e `assets/` — vai para o repositório.

---

## 7. Como expandir

| Quero… | Faça |
|---|---|
| Novo sistema no servidor | Copie um arquivo de `src/server/Services/`, renomeie e adicione o nome na lista de `init.server.luau` |
| Novo sistema no cliente | Mesmo processo em `src/client/Controllers/` e `init.client.luau` |
| Novo canal cliente ↔ servidor | Adicione o nome em `EVENTS` no `Remotes.luau` |
| Novo predador | Crie em `src/server/Predators/` usando `PredatorBase` e coloque os valores em `Config.Predators` |
| Nova região do mapa | Nova função em `World/MapBuilder.luau` + parte de região com atributo `RegionType` |
| Ajustar dificuldade | Só `src/shared/Config.luau` |

---

## 8. Problemas comuns

| Sintoma | Solução |
|---|---|
| `rojo` não é reconhecido | Feche e abra o PowerShell depois de instalar o Rokit; rode `rokit install` na pasta do projeto |
| Studio não conecta | Confira se o `rojo serve` está rodando e se a porta é `34872` |
| Mudança não aparece | O plugin desconectou: clique em Connect de novo |
| Script editado no Studio "voltou" | Normal: edite no VS Code |
| Selene reclama na primeira vez | Ele baixa a lista da API do Roblox; precisa de internet na primeira execução |
| Autocompletar não funciona | Confirme a extensão Luau Language Server e abra o VS Code **na pasta do projeto** |

---

## 9. O que foi verificado

- `rojo build` gera o place com a árvore esperada (Shared, Server, Client).
- Todos os arquivos passam no verificador de tipos do Luau (`luau-lsp analyze`) e no StyLua.
- A lógica da colmeia (espiral de 37 células sem sobreposição, progresso por pontos de favo) e a penalidade de carga foram testadas num interpretador Luau.
- Testados num interpretador Luau: ciclo de dia/noite sem saltos, custos de melhoria, regiões (o que é protegido e onde há disputa), níveis, migração de dados salvos, penalidade de derrota única e queda de carga única.
- As Etapas 0 e A rodaram no Studio. **Esta versão ainda não foi executada no Studio**: siga o roteiro em `docs/ROADMAP.md`.
