# Trocando peças por modelos 3D

Hoje tudo no mapa é montado por código com peças simples. Para chegar perto das imagens de referência, o jogo já está pronto para **usar modelos 3D no lugar das peças**, sem mexer em código.

## Nomes que o jogo reconhece

| Arquivo em `assets/` | Substitui |
|---|---|
| `Abelha.rbxm` | corpo da abelha de todos os jogadores |
| `Flor.rbxm` | flores comuns |
| `Girassol.rbxm` | girassóis |
| `Arvore.rbxm` | árvores do bosque |
| `Cogumelo.rbxm` | cogumelos |
| `Cristal.rbxm` | cristais roxos |

Sem o arquivo, o jogo continua usando as peças. Pode trocar um de cada vez.

## Passo a passo (no Studio)

1. Abra a **Caixa de ferramentas** (Toolbox) → aba **Loja do Criador** → **Modelos**.
2. Busque, por exemplo: `cartoon bee`, `stylized flower`, `low poly tree`, `mushroom`.
3. Prefira modelos com selo de criador verificado e muitos votos positivos.
4. Clique no modelo para inserir no Workspace.
5. **Abra o modelo no Explorador e apague qualquer Script dentro dele.** O jogo também remove scripts automaticamente, mas é bom conferir.
6. Renomeie o **Model** para o nome da tabela (ex.: `Flor`).
7. Clique com o botão direito no modelo → **Salvar em arquivo** → salve em
   `C:\Projetos Lua\reino-das-abelhas\assets\Flor.rbxm`
8. Apague o modelo do Workspace (ele agora vem da pasta `assets`).
9. Com o `rojo serve` rodando, aperte Play.

O jogo ajusta o **tamanho sozinho**: flores ficam com altura de flor gigante, a abelha fica com ~6 studs de comprimento, e assim por diante.

## Dicas

- **Abelha:** a frente do modelo precisa apontar para a frente (eixo -Z do Roblox). Se a abelha voar de lado, gire o modelo no Studio antes de salvar.
- **Desempenho:** modelos muito detalhados pesam no celular. Prefira "low poly".
- **Licença:** modelos da Loja do Criador podem ser usados em experiências do Roblox. Se for publicar e monetizar, confira a página do modelo.
- **Feito por você:** modelos feitos no Blender entram pelo **Importador 3D** do Studio (Arquivo → Importar 3D) e seguem o mesmo passo 6 em diante.
