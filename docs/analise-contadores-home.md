# Análise de viabilidade — Contadores da Home (Delivery App 6amMart)

## Resumo executivo
Sim, **dá para implementar** os 4 itens com bom alinhamento ao app atual e sem quebrar o padrão do projeto.

- `Entregas` já está compatível com dado nativo (`todaysOrderCount`) do `ProfileController`.
- A `Meta` pode ser persistida em `SharedPreferences` com baixo impacto.
- `Km Rodados` é viável, mas exige definir a fonte correta (não usar `order_amount` como km).
- `Horas Online` com resiliência depende de persistir e reaproveitar timestamp de início online.

## O que já existe e favorece a implementação

1. O app já recebe contadores diários no perfil (`todays_order_count` e `todays_earning`) e os mapeia no `ProfileModel`.
2. A Home já usa `ProfileController` e já mostra `todaysOrderCount` no card de entregas.
3. O projeto já possui uso consolidado de `SharedPreferences` em repositórios.
4. Há fluxo de ativação online/offline no `ProfileController.updateActiveStatus()`, que é o ponto ideal para salvar/remover “horário de início online”.

## Avaliação por requisito

### 1) Data Binding de “Entregas”
**Status:** já alinhado.

- Hoje o card “Entregas” já lê `profile?.todaysOrderCount ?? 0` na Home.
- Isso está 100% coerente com o backend 6amMart (campo nativo no profile).

### 2) Meta persistente + barra de progresso
**Status:** viável e simples.

Implementação sugerida:
- Criar chave de preferência, ex.: `home_daily_goal_value`.
- Ao iniciar a Home, carregar meta salva (com fallback, ex.: 200).
- Adicionar diálogo simples com `TextField` numérico para editar meta.
- Salvar a meta no `SharedPreferences`.
- Barra: `progress = (todaysEarning / goal).clamp(0, 1)` e `% = progress * 100`.

**Alinhamento com 6amMart:** alto, pois `todaysEarning` já vem nativo no perfil.

### 3) Cálculo de Km
**Status:** viável com ressalva de fonte de dados.

Pontos importantes:
- O `OrderModel` padrão não traz um campo explícito de “distância rodada real”.
- Existe latitude/longitude de loja e endereço de entrega, então é possível calcular distância geodésica estimada por pedido concluído.
- Usar `order_amount` como km **não é recomendado** (valor monetário, sem semântica de distância).

Estratégia de menor risco:
- Carregar pedidos concluídos (`getCompletedOrders(1)`), filtrar os de hoje.
- Somar distância estimada entre origem e destino por pedido.
- Exibir como “Km estimados” (ou similar) para evitar interpretação de telemetria real.

Se você quiser “km real rodado”, o ideal é API/log de rota com distância acumulada (backend).

### 4) Resiliência no horário de início online
**Status:** viável e importante.

Implementação sugerida:
- Quando mudar para online (`active = 1`), salvar timestamp `online_start_time` em `SharedPreferences` (se ainda não existir).
- Quando mudar para offline (`active = 0`), limpar a chave.
- No `onInit`/`initState` da Home:
  - se perfil está online e há `online_start_time`, continuar contador a partir dele;
  - se perfil está online e não há chave, salvar agora para iniciar corretamente;
  - se perfil offline, zerar UI de horas.

Assim o contador não zera em restart/refresh do app.

## Compatibilidade com o painel admin 6amMart

- **Totalmente alinhado** para os dados de entregas e ganhos do dia (nativos da API de profile).
- **Parcialmente alinhado** para km: painel pode usar lógica diferente; no app, sem endpoint de km, será estimativa local.
- **Neutro/seguro** para meta e horas online: são métricas de UX no app, não conflitam com dados financeiros/operacionais do admin.

## Riscos e mitigação

- **Risco:** divergência de “Km” entre app e admin.
  - **Mitigação:** rotular como estimado, ou criar endpoint dedicado de distância no backend.
- **Risco:** meta inválida (zero, negativa, texto).
  - **Mitigação:** validação de input e fallback para valor padrão.
- **Risco:** contador online incoerente após logout.
  - **Mitigação:** limpar chave de `online_start_time` no logout/clear shared data.

## Conclusão

A proposta é **executável** e **coerente com a arquitetura atual**.

Ordem recomendada de entrega:
1. Meta persistente (rápido, baixo risco).
2. Resiliência do horário online (baixo risco, alto valor).
3. Km estimado (com rótulo claro).
4. Opcional: endpoint backend para km real (alinhamento total com admin).
