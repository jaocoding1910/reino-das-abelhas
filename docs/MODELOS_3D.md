# Modelos 3D

O jogo funciona sem nenhum modelo: tudo é montado por código com peças simples. Com modelos 3D ele passa a usar formas arredondadas de verdade (abelha fofinha, flores com pétalas, cogumelos, árvores, cristais). Você não precisa mexer em código.

## Caminho rápido: o pacote pronto (`modelos3d/PacoteAbelhas.glb`)

O projeto já traz um pacote com 6 modelos feitos para o jogo, gerados por código (`modelos3d/gerador/`). Veja como ficam em `modelos3d/preview.png` e `modelos3d/abelha.png`.

| Modelo dentro do pacote | Substitui |
|---|---|
| `Abelha` | corpo da abelha de todos os jogadores (asas batem sozinhas) |
| `Flor` | flores comuns (cor das pétalas muda de flor para flor) |
| `Girassol` | girassóis |
| `Arvore` | árvores do bosque |
| `Cogumelo` | cogumelos (as pintas brilham à noite) |
| `Cristal` | cristais roxos |

### Importar (uma vez só, no Studio)

1. Abra o lugar com o `rojo serve` rodando e conecte o plugin do Rojo.
2. **Arquivo → Importar 3D** (em inglês: *File → Import 3D*).
3. Escolha `C:\Projetos Lua\reino-das-abelhas\modelos3d\PacoteAbelhas.glb`.
4. Na janela do importador, deixe tudo no padrão e clique em **Importar**. Aparece um Model **PacoteAbelhas** no Workspace com os 6 modelos dentro.
5. Clique com o botão direito em **PacoteAbelhas** → **Salvar em arquivo** (*Save to File*) → salve como
   `C:\Projetos Lua\reino-das-abelhas\assets\PacoteAbelhas.rbxm`
6. Apague o PacoteAbelhas do Workspace (agora ele vem da pasta `assets`).
7. Aperte **Play**.

**Não renomeie as peças de dentro** (`Corpo_1`, `Petala_3`…): o jogo usa a parte antes do "_" para pintar cada peça com as cores de `Config.Art.Palette`. Quer outra cor? Mude a paleta no `Config.luau`; não precisa importar de novo.

### Se algo ficar estranho

- **A abelha voa de costas ou de lado:** em `Config.luau`, troque `Config.Art.BeeYawDegrees` de `0` para `180` (ou `90` / `-90`).
- **As asas não batem:** confira se as peças das asas continuam com nome `AsaE_…` e `AsaD_…`.
- **Modelos pretos ou cinza:** normal antes do Play. O jogo pinta as peças ao montar o mapa.
- **Tudo igual a antes:** o arquivo precisa estar em `assets/` e o Rojo precisa estar conectado. No Explorer, confira se existe `ReplicatedStorage → Assets → PacoteAbelhas`.

### Mudar as formas

Os modelos são gerados por `modelos3d/gerador/modelos.py` (Python + numpy):

```powershell
cd "C:\Projetos Lua\reino-das-abelhas\modelos3d\gerador"
pip install numpy
python modelos.py ..\PacoteAbelhas.glb
```

Depois, importe de novo (passos 2 a 6).

## Caminho alternativo: modelos da Loja do Criador

Você também pode trocar um modelo de cada vez por um da Toolbox. O jogo procura pelo NOME do Model em qualquer lugar dentro de `assets/`.

1. **Caixa de ferramentas** (Toolbox) → **Loja do Criador** → **Modelos**. Busque, por exemplo, `cartoon bee`, `stylized flower`, `low poly tree`.
2. Prefira criadores verificados e modelos "low poly" (mais leves no celular).
3. Insira no Workspace e **apague qualquer Script dentro dele** (o jogo também remove scripts sozinho).
4. Renomeie o Model para o nome da tabela (ex.: `Flor`).
5. Botão direito → **Salvar em arquivo** → `assets\Flor.rbxm`. Apague do Workspace.

Modelos de terceiros não seguem a regra `Papel_n`, então mantêm as cores originais. O tamanho é ajustado sozinho. **Licença:** confira a página do modelo antes de publicar e monetizar.
