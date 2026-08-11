# Sistema de Bazaar (leilão de personagens) — documento de arquitetura

Status: **proposta, nenhum código escrito ainda**. Objetivo deste documento é dar
uma visão realista do escopo antes de comprometer tempo de implementação.

## 1. O que é o Bazaar oficial

No Tibia oficial, o Bazaar é o sistema onde jogadores colocam personagens à
venda em leilão (ou "Buy Now" direto), outros jogadores dão lances, e ao final
do leilão o personagem — com todos os itens, casa, conquistas, etc. — é
transferido para o comprador. Tem histórico de leilões, filtros de busca
(vocação, nível, mundo), status "Currently Trading" no personagem durante o
leilão, e uma taxa/moeda premium envolvida em alguns pontos.

## 2. O que já existe no nosso código (e o que não existe)

Procurei no Canary e no cliente antes de propor qualquer coisa:

- **Não existe nada de Bazaar** — nem opcode de protocolo, nem tabela de
  banco, nem módulo de UI no cliente. Seria construído do zero.
- **Existe um sistema irmão que serve de modelo**: o Market de itens
  (`src/io/iomarket.hpp/cpp`, tabelas `market_offers` e `market_history` no
  `schema.sql`, opcodes `parseMarketBrowse/CreateOffer/CancelOffer/AcceptOffer`
  em `protocolgame.cpp`). A arquitetura do Bazaar seguiria o mesmo formato:
  tabela de ofertas ativas + tabela de histórico + opcodes dedicados de
  protocolo + comparação periódica de expiração (`checkExpiredOffers`).

Ou seja: não é um território totalmente desconhecido — dá pra copiar o
*padrão* de engenharia do Market — mas o conteúdo em si (transferir um
personagem inteiro entre contas) é uma operação muito mais delicada do que
mover um item entre inventário e mercado.

## 3. Por que é maior que qualquer coisa feita até agora nesta sessão

Pra comparar: a troca de chave RSA foi só substituir um arquivo + uma
constante. O sistema de hunts instanciadas foi grande, mas trabalhou só com
zonas/monstros, nada irreversível por jogador. O Bazaar mexe em:

1. **Banco de dados** — novas tabelas (auctions, bids, histórico).
2. **Protocolo cliente-servidor** — opcodes novos dos dois lados.
3. **Cliente** — módulo de UI novo (não existe nada parecido pra copiar).
4. **Transferência de personagem** — a parte de risco real: mover conta de
   dono, todos os itens (inventário + depot + casa), guild membership,
   achievements, histórico, tudo isso **atomicamente** (ou tudo acontece ou
   nada acontece — sem estado intermediário quebrado).
5. **Dinheiro/moeda** — decisão de negócio: vai usar gold, Tibia Coins
   (ou equivalente), ou só transferência gratuita entre jogadores?

O item 4 é o que preocupa de verdade: um bug aqui pode duplicar personagem,
duplicar itens, ou fazer um personagem sumir. Isso não é hipotético — é o tipo
de bug que historicamente já afetou servidores oficiais e privados.

## 4. Proposta de escopo para uma v1 (reduzido)

Ao invés de tentar replicar o Bazaar oficial completo de uma vez, sugiro um
v1 propositalmente mais simples, ainda com valor real:

- Só **leilão simples com prazo fixo** (sem "Buy Now") — reduz decisões de
  negócio.
- **Sem filtros avançados de busca** no cliente inicialmente — lista simples.
- **Moeda: Tibia Coins transferíveis**, igual ao Tibia oficial (decisão do
  usuário — ver seção 5.1a).
- Transferência acontece só quando o leilão fecha, nunca durante.
- Anti-sniping: lance nos últimos minutos estende o prazo (confirmado como
  desejado, ver conversa).

## 4a. Checklist real de pré-requisitos (print do Tibia oficial)

O usuário mandou o print da tela real "Character Auction Settings (1/3)" do
Tibia oficial. Isso resolve várias das perguntas de Fase 0 de uma vez —
transcrevendo a lista completa de validações que o Tibia faz antes de deixar
colocar um personagem à venda:

1. O personagem só pode ter itens permitidos (alguns itens não-transferíveis
   bloqueiam o anúncio).
2. Não pode já ter outro leilão de troca de personagem aberto.
3. A conta não pode estar com conduct level laranja, vermelho ou preto.
4. Precisa ter Tibia Coins transferíveis suficientes pra criar o anúncio
   (**confirma que existe uma taxa cobrada em coins pra anunciar**).
5. **A conta precisa estar protegida por autenticação de dois fatores.**
6. O personagem precisa ter pelo menos **nível 8**.
7. O personagem não pode ser dono de nenhuma casa.
8. O personagem não pode estar com lance em andamento por uma casa.
9. O personagem não pode estar envolvido numa transferência de casa.
10. **O personagem não pode ser membro de guild** (no print, essa condição
    aparece como bloqueio quando o personagem testado está numa guild).
11. O personagem não pode ter aplicado pra uma guild.
12. **O personagem não pode ter oferta aberta no Market** (no print, aparece
    como bloqueio quando o personagem tem oferta ativa).
13. O personagem não pode estar agendado pra exclusão.
14. O personagem não pode estar marcado com skull (skull de combate).
15. Não pode haver transferência de mundo pendente pro personagem.
16. Não pode haver transação pendente na Store.
17. As compras da Store da conta precisam estar todas sincronizadas.
18. O personagem precisa estar numa protection zone no momento de anunciar.
19. O personagem não pode ter bloqueio de logout.
20. Não pode haver namelock aberto pro personagem.

### O que isso muda no nosso plano

- **Confirma** várias decisões que eu já tinha proposto por conta própria:
  sem casa, nível mínimo (agora sabemos que é 8, não um valor arbitrário),
  taxa em coins pra anunciar, e que ter oferta de Market aberta bloqueia.
- **Adiciona uma dependência que eu não tinha previsto**: exigir 2FA pra usar
  o bazaar. Isso conecta direto com a conversa que já tivemos sobre 2FA —
  lembrando que confirmei que **o nosso servidor não valida 2FA de verdade
  ainda** (a função existe em C++ mas não está ligada no fluxo de login).
  Se quisermos replicar essa regra fielmente, o sistema de 2FA completo
  (que também é um projeto à parte, com mudança em C++ + recompilação)
  vira **pré-requisito do Bazaar**, não uma feature independente.
  Duas saídas possíveis:
  - (a) fazer 2FA valer de verdade primeiro, depois o Bazaar exigir ele; ou
  - (b) no nosso v1, **não exigir 2FA** (é uma decisão nossa, não somos
    obrigados a copiar 100% do oficial) e revisitar isso quando/se o 2FA
    real for implementado.
- Itens específicos do ecossistema Store/World Transfer do Tibia oficial
  (16, 17, 15) não se aplicam a nós do mesmo jeito — não temos múltiplos
  mundos nem a mesma Store deles. Substituo por equivalentes nossos: sem
  transação de loja pendente (se tivermos fila de compra), sem processo de
  transferência de personagem já em andamento.

### Checklist adaptado pra nós (v1)

Validações que o **v1 realmente aplicaria** antes de aceitar o anúncio:

- [ ] Personagem nível 8+
- [ ] Personagem não é dono de casa
- [ ] Personagem não tem lance de casa em aberto
- [ ] Personagem não é membro de guild (nem aplicou)
- [ ] Personagem não tem oferta aberta no Market
- [ ] Personagem não tem skull de combate
- [ ] Conta não está com conduct level laranja/vermelho/preto
- [ ] Personagem não está agendado pra exclusão
- [ ] Personagem não tem outro leilão já aberto
- [ ] Personagem está numa protection zone no momento de anunciar
- [ ] Lance inicial >= 57 coins (mínimo fixo — ver 5.1b)
- [ ] Conta tem 50 `coins_transferable` disponíveis pra pagar a taxa de
      anúncio (cobrada na hora, ver 5.1b)
- [ ] **Personagem não é GM/staff** (decidido — ver 5.1c)
- [ ] Conta protegida por 2FA (decidido — 2FA será implementado junto, ver
      seção 7)

### 5.1b Taxa: confirmado pelo artigo oficial (tibiabr.com) — modelo de DUAS taxas

O artigo que o usuário trouxe confirma com precisão como o sistema oficial
funciona, e corrige a simplificação que eu tinha escrito antes. É
exatamente o modelo de duas taxas que eu tinha desenhado antes de tentar
simplificar demais — texto do artigo:

> "50 Tibia Coins serão pagos como taxa de leilão pelo vendedor ao
> configurar uma oferta. A CipSoft receberá uma comissão de 12% sobre o
> valor de venda. Deste modo, o lance mínimo será de 58 Tibia Coins, para
> garantir um mínimo de comissão paga: 50 TCs da taxa de leilão + 8 TCs do
> valor de venda (o vendedor recebe 7 TC, a CipSoft recebe 1 TC)."

Ou seja, confirmado:
1. **Taxa fixa de 50 TC**, paga pelo vendedor **na criação/confirmação do
   anúncio**, reservada imediatamente.
2. **Comissão de 12% sobre o valor final de venda**, descontada só se
   vender.
3. **Lance inicial mínimo de 57 TC** — corrigido: o usuário mandou um print
   de um leilão real, ao vivo, no site oficial ("Indigente Mazatleco",
   nível 140, Paladin), mostrando **"Minimum Bid: 57"**. Isso é mais
   confiável que o artigo do tibiabr.com (que dizia 58) — o site ao vivo é
   a fonte definitiva. E o número bate exatamente com a fórmula que eu
   tinha deduzido antes, por conta própria:

   ```
   57 × 0,88 = 50,16   → cobre a taxa fixa de 50 ✓
   56 × 0,88 = 49,28   → não cobre ✗
   ```

   Ou seja, **57 é o menor valor inteiro cujo líquido após a comissão de
   12% ainda cobre a taxa fixa de 50 TC** — a fórmula
   `lance_mínimo = arredondar_para_cima(taxa_fixa / (1 - taxa_comissão))`
   continua valendo, só a explicação do artigo (que decompunha como
   "50 + 8 TC do valor de venda") é que parece ter um errinho. Fica **57**
   como o valor confirmado e correto pra usarmos.

**Regras de reembolso/perda da taxa fixa de 50 TC** (detalhe novo e
importante do artigo, que eu não tinha):
- Se o vendedor **cancelar antes do leilão ir ao ar** (antes do próximo
  server save após a confirmação): os 50 TC são **reembolsados**.
- Se cancelar **depois de publicado** (já visível no Bazaar) mas **antes de
  qualquer lance**: os 50 TC são **perdidos** (debitados da conta).
- **Depois do primeiro lance, não é mais possível cancelar** — ponto final,
  nem perdendo a taxa. Confirmado no FAQ do artigo: "Uma vez que o primeiro
  lance tenha chegado, você não pode mais cancelar um leilão."
- Se o leilão for **anulado por falta de pagamento do comprador** (depois
  dos 7 dias, ver 5.1g): o vendedor recebe os 50 TC de volta como
  compensação, mesmo já tendo tido lance.

Ambas as taxas (50 TC fixo + 12% comissão) viram **sink** — destruídas, não
vão pro saldo de ninguém.

### 5.1d Retenção de 120 dias nos coins recebidos (anti-lavagem)

Outro detalhe do print 3/3, importante pro nosso lado:

> "Note that the Tibia Coins you receive for selling your character may be
> partly or completely **non-transferable** up to **120 days** after the
> auction has ended. Non-transferable Tibia Coins cannot be sold in the
> Market or gifted to other accounts."

Isso é uma proteção anti-fraude: sem isso, alguém poderia comprar coin com
dinheiro real, "vender" um personagem pra si mesmo (numa segunda conta) e
teoricamente reciclar isso, ou golpistas poderiam vender personagens
comprados com cartão roubado e sacar o valor rápido antes do estorno.
Prendendo o coin recebido por um tempo, dá margem pra investigar antes do
valor circular livremente.

Recomendo replicar isso no v1: os coins que o vendedor recebe entram como
**não-transferíveis** por um período (não precisa ser 120 dias exatos, pode
ser um valor nosso, ex: 30 dias) antes de virarem `coins_transferable` de
verdade. Tecnicamente: creditar em `coins` (não-transferível) com um
registro de quando isso pode ser "promovido" pra `coins_transferable`, e uma
globalevent diária que faz essa promoção quando o prazo vence.

### 5.1c GM/staff não pode ser leiloado

Decisão do usuário, confirmada. Checagem simples: se
`player:getAccountType() >= ACCOUNT_TYPE_GAMEMASTER`, bloqueia a criação do
anúncio (mesma constante já usada no `anti_bot_monitor.lua` que criamos).

### 5.1e Outros detalhes dos prints e do artigo

- **Vendedor escolhe a data/hora exata de término**, dentro de uma janela de
  **2 a 28 dias** a partir da configuração (confirmado pelo artigo). Bate
  com o schema (`ends_at` já é um timestamp livre) — só precisa validar
  esse intervalo no momento de criar o anúncio.
- **Itens de destaque**: até **4 itens** raros/valiosos + até **5 skills**
  + achievements/outras características — não é "5 argumentos" genéricos
  como eu tinha escrito, são duas listas separadas (itens e skills). Ainda
  assim, sugiro **deixar de fora do v1** — é só vitrine, não afeta a
  mecânica.
- **Aviso de segurança**: antes de confirmar, o Tibia avisa pra remover
  cartas/documentos com dados sensíveis (endereço, senha) do inventário e
  depot, porque isso **não é limpo automaticamente** na transferência. Vale
  reusar esse aviso literalmente na nossa tela de confirmação.
- **Início no próximo "server save"**: o leilão só aparece publicamente no
  Bazaar a partir da próxima manutenção diária, não instantaneamente — mas
  (ver 5.1h abaixo) o personagem já fica travado a partir da confirmação,
  então esse detalhe é só sobre quando OUTRAS pessoas passam a ver/dar
  lance, não sobre quando o vendedor perde acesso.
- **Sem transferência direta, só leilão público**: o Tibia decidiu de
  propósito não ter opção de "presentear"/transferir personagem direto pra
  uma conta específica — só dá pra colocar em leilão público, mesmo que a
  intenção seja vender pra alguém específico (e correr o risco de outra
  pessoa dar lance maior). Isso é deliberado, pra evitar fraude (FAQ do
  artigo: "Decidimos não oferecer outras opções para evitar cenários de
  fraude."). **Recomendo manter esse princípio no nosso v1** — não criar
  atalho de "transferir personagem X pra conta Y" fora do leilão.
- **E-mails de notificação**: o Tibia manda e-mail em cada etapa (publicado,
  alguém deu lance, você foi superado, você ganhou, lembrete de pagamento,
  venda concluída). Nós não temos infraestrutura de e-mail transacional
  pronta — sugiro **substituir por mensagens in-game** (system message no
  login seguinte) no v1, e considerar e-mail como polimento de fase
  posterior.
- **Marcação "(traded)"**: personagens que trocaram de mãos nos últimos 30
  dias ficam marcados em chat, fórum e na página de personagens. É uma
  feature de transparência/confiança legal, mas não essencial — **fase
  posterior**.
- **Limite de personagens conta os lances ativos**: se sua conta está perto
  do limite de personagens, seus lances em andamento contam nesse limite
  (você não pode arriscar ganhar mais personagens do que cabe na conta).
  Validação a adicionar na hora de aceitar um novo lance.
- **VIP list e friend list são apagadas**: ao vender, a VIP list e friend
  list do próprio personagem são zeradas, e ele é removido de qualquer VIP
  list/friend list de outros jogadores que o tinham adicionado. Passo a mais
  pra incluir na Etapa B da transferência (5.3).

### 5.1h Travamento do personagem ao confirmar o anúncio (detalhe crítico que eu não tinha)

O artigo revela um comportamento que eu **não tinha previsto** e que é
importante pra segurança do sistema:

> "Uma vez que o leilão tenha sido configurado e confirmado, você perderá
> imediatamente o acesso ao seu personagem, sendo deslogado e não podendo
> mais efetuar login nele."

Ou seja: assim que o vendedor confirma o anúncio (tela 3/3), ele é
**deslogado na hora** e **não consegue mais logar** nesse personagem — nem
pra "esvaziar" itens de valor, nem por engano. Isso vale durante **todo o
tempo** que o personagem está em leilão (até vender, ser cancelado ou
anulado). Sem isso, o vendedor poderia anunciar o personagem, deixar
rodando, e continuar jogando/mudando o personagem depois — quebrando a
integridade do que o comprador está vendo/comprando.

**Pra nós, isso vira uma trava obrigatória**: ao confirmar
`parseBazaarCreateAuction` com sucesso, o servidor deve desconectar o
personagem se estiver online e recusar login nele (`AccountErrors_t` custom
ou checagem equivalente em `protocollogin.cpp`/`ProtocolGame::login`)
enquanto `bazaar_auctions.state` for `active`, `pending_payment`, ou
enquanto o leilão não for `cancelled`/`voided`.

### 5.1i O que é transferido com o personagem vs. o que fica na conta

O artigo lista, campo por campo, o que é da **conta** (nunca se move) e o
que é do **personagem** (vai junto na venda). Isso resolve de vez a
pergunta "o que exatamente a Etapa B da transferência precisa tocar":

**Fica na conta (NUNCA transferido):** loyalty, dados de registro, e-mail,
Tibia Coins, recovery key, senha, autenticador (2FA), histórico de punições,
premium time, outfits de conta, mounts de conta, Tournament tickets não
atribuídos a um personagem.

**Vai com o personagem (transferido):** data de criação, nome, XP, skills,
gold (bank/depot/inventário), itens normais (depot/stash/inbox/inventário),
itens de Store (inventário/inbox de Store), hirelings + jobs + outfits de
hireling, mounts normais e de Store, outfits normais e de Store, blessings,
imbuements, charms + charm points (disponíveis e gastos) + expansão de
charm, sequência de recompensa diária, pontos de task de caça, slot
permanente de task/prey, áreas completas da Cyclopedia, quests completadas,
títulos, achievements + pontos, progresso do bestiário. **Mais o que já
tínhamos identificado**: VIP list e friend list são **apagadas** (não
transferidas, ver 5.1e).

**Mapeando pro nosso lado**: a regra geral que replicamos é *"tudo que é
coluna/tabela do personagem (`players.*` e tabelas com `player_id`) muda de
dono; tudo que é `accounts.*` nunca muda"*. Como `players.account_id` é o
único campo que precisa mudar (passo 2 da Etapa B em 5.3), na prática **não
precisamos mover dado nenhum linha por linha** — todo o resto (itens,
depot, skills, achievements, bestiário, etc.) já está automaticamente
"vinculado" ao personagem certo via `player_id`, e muda de dono junto
quando só o `account_id` do personagem é atualizado. Isso é uma boa notícia:
simplifica bastante a Etapa B, desde que nosso schema já siga essa
convenção (não guarda nada de personagem numa tabela indexada por
`account_id`, o que seria incomum).

## 5. Arquitetura proposta (v1)

### 5.1a Moeda: Tibia Coins transferíveis (infraestrutura já existe)

Achei no `schema.sql` que a tabela `accounts` já tem exatamente o que
precisamos, pronto:

```sql
`coins` int(12) UNSIGNED NOT NULL DEFAULT '0',              -- coins normais
`coins_transferable` int(12) UNSIGNED NOT NULL DEFAULT '0', -- estas sim, transferíveis entre contas
`tournament_coins` int(12) UNSIGNED NOT NULL DEFAULT '0',
```

Isso bate com o próprio Tibia oficial: coin comprado (transferível) é o que
circula em trocas entre contas; coin ganho por outros meios geralmente não é.
O Bazaar deve mexer **só em `coins_transferable`**, nunca em `coins` puro —
assim não criamos coin do nada nem permitimos "lavar" coin não-transferível.
Coins são por **conta**, não por personagem, o que simplifica: o lance é
descontado/creditado direto na conta, sem precisar rotear por um personagem
específico.

### 5.1g Mecânica real de lance: "proxy bidding" (limite secreto)

O usuário mandou a explicação oficial completa de como o lance funciona no
Tibia, e é bem mais sofisticado do que "cada lance é um valor público que
supera o anterior". É o mesmo modelo do eBay clássico: você não dá lance no
valor que vai pagar, você dá um **limite secreto** (o máximo que toparia
pagar), e o sistema só cobra o mínimo necessário pra você continuar na
frente.

**O exemplo que o usuário deu, conferido número por número:**

| Evento | Limite de X | Limite de Y | Lance mínimo (público) | Quem está na frente |
|---|---|---|---|---|
| Início (preço inicial 700) | - | - | 700 | - |
| X envia limite 900 | 900 | - | 701 | X |
| Y envia limite 800 | 900 | 800 | 801 | X (900 > 800) |
| Y envia novo limite 1000 | 900 | 1000 | 901 | Y (1000 > 900) |

Fórmula que reproduz exatamente esses números:

```
lance_mínimo_visível = min( maior_limite, segundo_maior_limite_ou_preço_inicial + incremento )
```

Onde `incremento = 1` (pelo menos nesse exemplo — pode ser configurável).
Confirmando: `min(900, 700+1) = 701` ✓, `min(900, 800+1) = 801` ✓,
`min(1000, 900+1) = 901` ✓. Quem vence paga o **lance mínimo visível no
momento em que o leilão fecha** (901 no exemplo), nunca o próprio limite
secreto (Y nunca paga os 1000 que ofereceu, só o suficiente pra vencer X).

**Reserva de fundos**: ao enviar um limite, reserva-se
`max(51, arredondar_para_cima(limite × 0.10))` em `coins_transferable` da
conta — essa quantia fica bloqueada (inacessível pra outra coisa) enquanto o
lance estiver valendo. Se o jogador manda um **novo** limite (maior),
recalcula-se a reserva do zero com base no novo limite (não soma com a
reserva antiga — ela é substituída). Exemplo do usuário: limite 1000 → 100
reservados; novo limite 2000 → 200 reservados (não 300).

**No fechamento do leilão**:
1. Tenta cobrar o `lance_mínimo_visível` final da conta do vencedor
   automaticamente, usando o que já estava reservado + saldo disponível.
2. Se tiver fundo suficiente: cobra, transfere o personagem.
3. Se **não** tiver fundo suficiente: o vencedor tem **7 dias** pra
   completar o pagamento manualmente pelo Bazaar. O personagem fica
   reservado pra ele nesse meio tempo (não é oferecido a mais ninguém).
4. Se passar os 7 dias sem pagar: os TC que estavam reservados são
   **subtraídos da conta como penalidade**, e o leilão é anulado (o
   personagem volta pro vendedor / pode ser relistado — decisão em aberto).

Isso é significativamente mais complexo que o "lance simples, maior valor
vence" que eu tinha desenhado antes — mas está bem especificado agora graças
ao detalhamento do usuário, então dá pra implementar exatamente assim.

### 5.1 Banco de dados

```sql
CREATE TABLE bazaar_auctions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    player_id INT NOT NULL,           -- personagem sendo leiloado
    seller_account_id INT NOT NULL,
    starting_bid BIGINT NOT NULL,     -- preço inicial, em coins_transferable (mínimo 57, ver 5.1b)
    listing_fee_paid BIGINT NOT NULL DEFAULT 50, -- taxa fixa cobrada na criação (ver 5.1b)
    current_bid BIGINT NOT NULL DEFAULT 0,   -- "lance mínimo visível" (ver 5.1g), não o limite secreto de ninguém
    current_bidder_account_id INT NULL,      -- quem está na frente agora
    ends_at INT NOT NULL,             -- timestamp; estendido por lance de última hora (anti-sniping)
    state ENUM('active','sold','pending_payment','expired','cancelled','voided') NOT NULL DEFAULT 'active',
    payment_due_at INT NULL,          -- prazo de 7 dias pra pagar, se 'pending_payment'
    created_at INT NOT NULL,
    FOREIGN KEY (player_id) REFERENCES players(id) ON DELETE CASCADE
);

-- uma linha por conta que já deu lance neste leilão; o limite é atualizado
-- (UPSERT) quando a mesma conta manda um limite novo, não se acumula histórico linha a linha
CREATE TABLE bazaar_bids (
    id INT AUTO_INCREMENT PRIMARY KEY,
    auction_id INT NOT NULL,
    bidder_account_id INT NOT NULL,
    bid_limit BIGINT NOT NULL,        -- o valor MÁXIMO secreto do jogador, nunca exposto a outros jogadores
    reserved_amount BIGINT NOT NULL,  -- max(51, 10% do bid_limit)
    updated_at INT NOT NULL,
    UNIQUE (auction_id, bidder_account_id),
    FOREIGN KEY (auction_id) REFERENCES bazaar_auctions(id) ON DELETE CASCADE
);
```

`bazaar_history` pode ser dispensada no v1 — a própria tabela `bazaar_auctions`
com `state != 'active'` já serve de histórico.

**Anti-sniping**: se um lance chegar com menos de N minutos (ex: 5) pro fim,
soma-se mais N minutos em `ends_at` em vez de fechar na hora. Simples de
implementar, só precisa recalcular `ends_at` dentro da mesma transação do
lance.

### 5.2 Protocolo (novos opcodes, no padrão do Market)

Server-side (`protocolgame.hpp/cpp`, ao lado dos `parseMarket*`):
- `parseBazaarBrowse` — listar leilões ativos
- `parseBazaarCreateAuction` — colocar o próprio personagem à venda
- `parseBazaarPlaceBid` — enviar/atualizar o limite de lance (5.1g)
- `parseBazaarCancelAuction` — cancelar (só permitido antes do primeiro
  lance, ver regras de reembolso/perda da taxa em 5.1b)
- `parseBazaarCompletePayment` — finalizar pagamento manual de um leilão
  `pending_payment` dentro do prazo de 7 dias
- `sendBazaarEnter` / `sendBazaarUpdate` — respostas ao cliente

### 5.3 Fechamento do leilão e transferência (o núcleo de risco)

Com o mecanismo de proxy bidding (5.1g), fechar um leilão tem duas etapas
separadas: **tentar cobrar** e, só se isso funcionar, **transferir**.

**Etapa A — no vencimento (`ends_at`), rodando pra todo leilão `active`
com pelo menos um lance:**

1. `preço_final = current_bid` (o lance mínimo visível no momento do
   fechamento — não o limite secreto de ninguém).
2. Verificar se a conta vencedora tem `coins_transferable` disponível
   (reservado + livre) >= `preço_final`.
3. **Se sim** → cobrar `preço_final` da conta vencedora (usando primeiro o
   que já estava reservado) e ir pra Etapa B (transferência) imediatamente.
4. **Se não** → marcar o leilão como `pending_payment`, `payment_due_at =
   agora + 7 dias`. Personagem fica reservado pro vencedor, ninguém mais
   pode dar lance. Uma globalevent diária verifica leilões
   `pending_payment` vencidos: se `payment_due_at` passou sem pagamento
   manual, subtrai o valor **reservado** (não o `preço_final` inteiro) da
   conta como penalidade, marca o leilão como `voided`, **e devolve os 50 TC
   da taxa de anúncio pro vendedor** (confirmado pelo artigo — o vendedor
   não fica no prejuízo por causa de um comprador que não pagou).

**Etapa B — transferência (só roda depois que o pagamento foi confirmado,
seja na hora ou depois dos 7 dias), numa única transação de banco:**

1. Calcular a comissão de 12% sobre `preço_final`; o resto (88%) é o que o
   vendedor recebe. Creditar isso em `coins` **não-transferível** da conta
   do vendedor (não em `coins_transferable` direto), com data de liberação
   (ver 5.1d) pra promoção futura. Os 12% viram sink. (A taxa fixa de 50 TC
   já foi cobrada na criação do anúncio — aqui não mexe nela.)
2. Atualizar `players.account_id` do personagem para a conta do comprador
   — per 5.1i, isso sozinho já "leva junto" todo o resto (itens, skills,
   achievements, etc.), já que tudo é indexado por `player_id`.
3. Apagar a VIP list e friend list do personagem vendido, e removê-lo de
   qualquer VIP list/friend list de outros jogadores (5.1e).
4. Remover a trava de login do 5.1h (o personagem volta a poder logar,
   agora pra conta do comprador).
5. Casa e guild não precisam de tratamento especial aqui: a validação da
   seção 4a já bloqueia personagem com casa ou em guild **no momento de
   anunciar**, então nunca chega um personagem nesses estados até aqui.
6. Liberar as reservas de **todos os outros** licitantes perdedores desse
   leilão (o dinheiro deles nunca foi debitado, só estava reservado).
7. Registrar em log/auditoria antes de fechar a transação, não depois.
8. Commit. Se qualquer passo falhar antes do commit, rollback total.
9. Personagem só aparece de fato na lista do comprador **no próximo server
   save** (confirmado pelo artigo — bate com o já existente
   `global_server_save` globalevent, é só o momento em que a mudança de
   `account_id` passa a valer pra character list).

Ponto crítico: isso só deve rodar quando o personagem está **offline** e
idealmente com o servidor sabendo que ele não pode logar durante o processo
(um mutex/lock por personagem, ou processar isso só na globalevent de save,
quando o mundo já está num estado consistente).

### 5.4 Cliente

Módulo novo (`modules/game_bazaar/`), inspirado no `game_market` existente:
janela com lista de leilões, tela de detalhe do personagem (nível, vocação,
itens visíveis), campo de lance, aba "meus leilões".

### 5.5 Site (opcional, fase posterior)

Página de navegação do bazaar no MyAAC, similar ao que already existe pra
highscores — só leitura, não critical path.

## 6. Plano faseado sugerido

1. **Fase 0** — decisões de produto. **Tudo resolvido** agora, confirmado
   pelos prints (incluindo um leilão real ao vivo no site) + artigo do
   tibiabr.com: taxa fixa de 50 TC na criação + comissão de 12% na venda
   (5.1b), lance mínimo 57 TC, retenção de 120 dias no coin recebido
   (5.1d), travamento de login ao anunciar (5.1h), GM não pode ser
   leiloado, 2FA será implementado como parte do projeto (não pulado), sem
   transferência direta fora do leilão (5.1e).
2. **Fase 1 — 2FA de verdade primeiro.** Como o Bazaar agora depende de 2FA
   real, essa vira pré-requisito, não trabalho paralelo. Isso significa:
   adicionar o campo de segredo TOTP por conta, ligar a checagem de token no
   `protocollogin.cpp`, tela de ativação (site ou comando in-game — já
   discutimos as duas opções), e **recompilar o Canary**. Só depois disso
   dá pra exigir 2FA de verdade no Bazaar em vez de simular.
3. **Fase 2** — banco + lógica de transferência de personagem sozinha,
   testada via comando de GM direto (sem UI, sem protocolo ainda) numa cópia
   de teste do banco, não no servidor ao vivo.
4. **Fase 3** — opcodes de protocolo + lógica de leilão (criar, dar lance
   via proxy bidding, expirar, cobrar as duas taxas), ainda sem UI bonita —
   pode testar via packet manual/log.
5. **Fase 4** — UI no cliente.
6. **Fase 5** — página no site (opcional).

Cada fase testada isoladamente antes de avançar. A Fase 1 (2FA) e a Fase 2
(transferência) são as que mais merecem tempo de teste — são as únicas duas
partes deste projeto que mexem em coisa irreversível (autenticação de conta e
dono de personagem).

## 7. Recomendação

Com a decisão de incluir 2FA de verdade, o projeto cresceu: agora são dois
subsistemas novos (2FA + Bazaar), sendo o 2FA um bloqueador de tudo o resto.
Ainda vale a pena fazer, mas como projeto à parte com tempo dedicado — não em
cima de uma sessão que já estava lidando com outras mudanças. Sugiro começar
pela **Fase 1 (2FA)** sozinha, validar que funciona de verdade (login real
pedindo token, rejeitando token errado) antes de tocar em qualquer coisa do
Bazaar.

## 8. Passo a passo técnico detalhado

Cada fase da seção 6, quebrada em passos concretos. Isso é o checklist pra
seguir quando começarmos de verdade — não precisa ser feito tudo de uma vez,
mas cada Fase só começa depois da anterior estar testada.

### Fase 1 — 2FA real

**1.1. Descoberta técnica completa (revisada — a versão anterior deste
documento estava olhando pro lugar errado)**: fui direto na implementação
real do login clássico no cliente
(`Client/otclient-main/modules/gamelib/protocollogin.lua`, é Lua puro, não
C++ — o `ProtocolLogin` referenciado em `entergame.lua` não existe como
classe C++ separada nesse fork). Achei que:

- O token **já é enviado hoje, em todo login**, na própria conexão de
  login (porta 7171), não na conexão de mundo. Ele vai como um **segundo
  bloco RSA**, logo depois do bloco principal (que tem conta+senha+XTEA
  key):

  ```lua
  -- Client/otclient-main/modules/gamelib/protocollogin.lua, sendLoginPacket()
  msg:addString(self.accountName)
  msg:addString(self.accountPassword)
  ...
  msg:encryptRsa()  -- fecha o primeiro bloco RSA (conta+senha+XTEA)

  if g_game.getFeature(GameAuthenticator) then
      msg:addU8(0)  -- primeiro byte RSA precisa ser 0
      msg:addString(self.authenticatorToken)
      ...
      msg:encryptRsa()  -- segundo bloco RSA, só com o token
  end
  ```

- A feature `GameAuthenticator` **já está habilitada automaticamente** pra
  qualquer protocolo >= 1072 (`modules/game_features/features.lua`), e
  nosso protocolo é 1525 — ou seja, **o segundo bloco RSA com o token já
  está sendo enviado em todo login nosso, agora mesmo**, só que vazio
  (string vazia, já que não pedimos token a ninguém hoje).
- O servidor (`ProtocolLogin::onRecvFirstMessage` em
  `protocollogin.cpp`) faz **só um** `Protocol::RSA_decrypt(msg)` hoje, lê
  a XTEA key, account descriptor e senha — e **nunca lê o segundo bloco
  RSA**. Como o parser não tenta ler além do que pede explicitamente, isso
  não quebra nada hoje (os bytes extras simplesmente ficam sem ser lidos e
  são descartados) — mas também significa que o token nunca chega a
  lugar nenhum pra ser validado.
- O cliente já sabe reagir a dois opcodes de resposta específicos de
  token, prontos pra usar: `LoginServerTokenSuccess = 12` e
  `LoginServerTokenError = 13` (esse último já mostra "Invalid
  authenticator token." pro jogador, sem precisar mexer no cliente).

**Conclusão prática**: diferente do que eu tinha escrito antes (que exigia
mudar o protocolo em duas pontas, cliente e servidor), **o cliente já está
100% pronto** — não precisa mudar nenhuma linha do lado do cliente pra
mandar o token. O trabalho real é **só do lado do servidor**:

**1.2. Passos concretos de implementação** (`src/server/network/protocol/protocollogin.cpp`):
1. Depois de ler `password = msg.getString()` (linha ~34 da função
   `getCharacterList`, ou antes, dentro de `onRecvFirstMessage` onde os
   dados crus chegam), chamar `Protocol::RSA_decrypt(msg)` **de novo** pra
   abrir o segundo bloco, e ler o byte `0` + a string do token.
2. Depois de `account.load()` e `account.authenticate(password)` passarem,
   checar se a conta tem 2FA ativo (nova coluna, ver 1.3). Se sim, validar
   o token lido contra `generateToken()` (`src/utils/tools.cpp`, já existe,
   hoje sem call sites).
3. Se inválido/ausente com 2FA ativo: responder com o opcode
   `LoginServerTokenError` (13) em vez do erro genérico — o cliente já
   sabe mostrar a mensagem certa sem mudança nenhuma.
4. Se válido (ou conta sem 2FA ativo): segue o fluxo normal, manda a
   character list como já faz hoje.

**1.3. Schema**: decidir se usamos a coluna `accounts.key` que já existe
(parece genérica, precisa confirmar o que já é usado pra) ou criar uma
nova coluna dedicada, ex. `accounts.totp_secret VARCHAR(32) NULL` (base32,
padrão TOTP/Google Authenticator) + `accounts.totp_enabled TINYINT(1)
DEFAULT 0`.

**1.4. Geração/validação do token**: reaproveitar `generateToken(secret,
ticks)` que já existe em `src/utils/tools.cpp` (hoje sem nenhum call site —
código morto). Escrever a função de comparação com tolerância de ±1 janela
de 30s (padrão TOTP, pra tolerar pequena diferença de relógio entre
cliente/servidor).

**1.5. (já coberto pelo passo 1.2 acima — removido pra não duplicar).**

**1.6. Ativação pelo jogador**: um comando in-game (`!2fa enable`) que
gera um secret aleatório, salva em `totp_secret` (ainda com
`totp_enabled=0`), e mostra o secret em texto puro pro jogador configurar
no Google Authenticator manualmente (sem QR code — gerar QR de verdade
exigiria imagem, fora de escopo do chat). Um segundo comando
(`!2fa confirm <código>`) valida o primeiro token antes de virar
`totp_enabled=1` de fato — evita ativar com um secret que o jogador
digitou errado no app dele e ficar trancado pra sempre.

**1.7. Recompilar e testar**: build local do Canary com as mudanças,
testar em ambiente separado (não no servidor ao vivo) com uma conta de
teste: habilitar 2FA, tentar entrar sem token (deve pedir), com token
errado (deve rejeitar), com token certo (deve entrar). Só depois disso
subir pro servidor real.

### Fase 2 — Schema do Bazaar

**2.1.** Escrever as migrations SQL de `bazaar_auctions` e `bazaar_bids`
(seção 5.1), seguindo o padrão de `data-otservbr-global/migrations/*.lua`
já usado no projeto (vi o arquivo `21.lua` mexendo em `market_offers`,
mesmo padrão serve de modelo).

**2.2.** Adicionar as colunas de retenção de coin em `accounts` (5.1d):
algo como `accounts.coins_locked BIGINT DEFAULT 0` +
`accounts.coins_locked_until INT DEFAULT 0`, ou uma tabela separada
`bazaar_coin_holds` se quisermos suportar múltiplas liberações com prazos
diferentes ao mesmo tempo (mais correto, mas mais trabalho — decidir na
hora).

**2.3.** Globalevent diária (`data/scripts/globalevents/`) que promove
coin retido pra `coins_transferable` quando o prazo vence.

### Fase 3 — Lógica de transferência (sozinha, sem protocolo)

**3.1.** Escrever a função de transferência (Etapa B da seção 5.3) como
função Lua isolada, testável via comando de GM
(`data/scripts/talkactions/god/`), sem nenhuma UI ou protocolo novo ainda.

**3.2.** Testar num **banco de teste separado** (cópia do banco ao vivo,
não o banco de produção) — casos de sucesso, e casos de falha forçada em
cada passo (simular erro no meio pra confirmar que o rollback funciona e
não deixa personagem "duplicado" ou "órfão").

**3.3.** Só depois de confiante nisso, considerar testar num personagem
descartável no servidor real.

### Fase 4 — Protocolo + lógica de leilão

**4.1.** Adicionar os opcodes novos em `protocolgame.hpp/cpp` (seção 5.2),
ao lado dos `parseMarket*` existentes, seguindo exatamente o mesmo padrão
de registro no switch de opcodes.

**4.2.** Implementar `parseBazaarCreateAuction` com todas as validações da
checklist (seção 4a adaptada).

**4.3.** Implementar `parseBazaarPlaceBid` com a lógica de proxy bidding
(5.1g) — essa é a parte matematicamente mais delicada, vale escrever
testes unitários se o projeto tiver estrutura de testes em C++ (conferir
pasta `tests/`).

**4.4.** Implementar `parseBazaarCancelAuction` e
`parseBazaarCompletePayment`.

**4.5.** Globalevent de expiração (Etapa A da seção 5.3).

**4.6.** Testar sem UI — via log/print no console, ou um cliente de teste
que manda o packet manualmente.

### Fase 5 — Cliente

**5.1.** Módulo novo `modules/game_bazaar/`, usando `modules/game_market/`
como referência de estrutura (otui + lua).

**5.2.** Telas: lista de leilões, detalhe do personagem, campo de lance,
aba "meus leilões"/"meus lances".

**5.3.** Distribuir via o updater automático que já construímos nesta
sessão (o pipeline de manifest + deploy já existe e funciona).

### Fase 6 — Site (opcional)

**6.1.** Página read-only no MyAAC pra navegar leilões (não
obrigatória pro sistema funcionar, já que o cliente in-game cobre o
essencial).
