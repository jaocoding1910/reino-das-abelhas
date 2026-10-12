# Arquitetura

## Visão geral

```
CLIENTE (cada jogador)                         SERVIDOR (autoridade)
──────────────────────                         ─────────────────────
InputController ──┐                            PlayerDataService (DataStore)
FlightController  │   pede ações               WorldService (MapBuilder) · RegionService
CameraController  ├── Remotes / Prompts ──►    ResourceService · InventoryService · DropService
VisualController  │   (Upgrade, Cosmetic,      HiveService · UpgradeService · CosmeticService
HUDController  ◄──┘    HiveAction, Attack)     HealthService · PredatorService (Spider) · CombatService
       ▲                                       ProgressionService · DayNightService · CharacterService
       └──── StateUpdated / Notify / Effect / WorldUpdated ◄── StateService (via Lib/Notifier)

ReplicatedStorage.Shared: Config · Types · Remotes · Regions · Levels · Util
```

## Interações no mundo

Coleta, entrega e construção usam **ProximityPrompt**: funciona igual no PC (tecla E), controle e celular (toque), e o servidor recebe o `Triggered` direto do motor. O servidor ainda confere tempo segurado, distância, dono da colmeia, frequência e capacidade.

Os serviços avisam mudanças com `Lib/Notifier` (`Changed` e `Notify`). O `StateService` escuta e envia o estado completo ao HUD. Assim nenhum serviço depende do outro em ciclo.

## Ciclo de vida

Servidor e cliente usam o mesmo `Util/Loader`:

1. **Init** de todos os módulos, na ordem do bootstrap (preparar estado).
2. **Start** de todos os módulos, na mesma ordem (conectar eventos, loops).

Um módulo com erro é registrado no Output e os outros continuam.

## Regras de segurança (servidor manda)

O cliente **só pede**. O servidor sempre confere:

- **Distância** entre a abelha e o recurso, alvo ou colmeia.
- **Propriedade:** a colmeia é do jogador que pediu.
- **Frequência:** intervalo mínimo entre ações (`Config.Collection.MinIntervalBetweenActions`).
- **Capacidade** de carga e **custo** em mel/favos.
- **Disponibilidade:** o recurso existe e não está travado por outro jogador.
- **Região:** combate só em área de disputa; nada de dano em área protegida.

Nunca aceite do cliente: dano, quantidade, raridade, recompensa ou posição de outro jogador.

## Dados

| Dado | Onde vive | Salvo? |
|---|---|---|
| Mel, melhorias, cosméticos, título, células | `Profile` (PlayerDataService) | Sim, DataStore |
| Néctar e favos **carregados** | InventoryService (memória) | Não |
| Estado de flores/favos no mapa | ResourceService (memória) | Não |

**Desconexão durante a expedição:** a carga transportada é perdida. Assim, sair e entrar de novo nunca duplica recursos.

**Falha ao carregar o perfil:** a sessão fica sem salvar, para nunca gravar um perfil vazio por cima de um existente.

## Pontos de extensão

- **Predadores:** todos herdam `Predators/PredatorBase` (território, área protegida e aviso de ataque são regras comuns).
- **Regiões:** cada região é uma função em `World/MapBuilder` + uma parte com atributo `RegionType`.
- **Clãs:** o perfil já reserva `ClanId`; nada de alianças ou guerras implementado ainda.
- **Raridades épica/lendária:** adicionar em `Config.Rarities`, `Config.RarityOrder` e no tipo `Rarity`.
