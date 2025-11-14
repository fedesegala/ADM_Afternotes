
#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *
#show: show-theorion
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#import "../lib.typ": *

// apply numbering up to h3
#show heading: it => {
  if (it.level > 3) {
    block(it.body)
  } else {
    block(counter(heading).display() + " " + it.body)
  }
}

= Gestione di Dati Distribuiti
Dopo aver introdotto varie famiglie di basi di dati, e aver visto come in moltissimi contesti, la loro nascita è dovuta al fatto di permettere una scalabilità orizzontale, andremo ora a vedere come effettivamente queste basi di dati permettono di gestire *dati distribuiti* su diversi nodi.

== Concetti di Base
Come già menzionato, il principio alla base delle basi di dati distribuite è quello della *scalabilità*. Nel particolare, esistono due tipologie di scalabilità di cui si può parlare:

- *Scale up* (o _verticale_): consiste nell'aggiunta di più potenza computazionale ad un singolo server che ospita la base di dati. Questo consente tipicamente di migliorare le prestazioni, ma ha dei limiti fisici e di costo.
- *Scale out* (o _orizzontale_): consiste nell'aggiunta di più nodi (server) al sistema di database. Questo approccio consente di distribuire il carico di lavoro e i dati.

Quando andiamo a parlare di basi di dati distribuite, andremo a riferirci alle seguenti componenti fondamentali:

- *Database distribuito*: si tratta di un insieme di dati che sono _logicamente interconnessi_
- *DBMS distribuito*: si tratta si un sistema per la gestione di _database distribuiti_, che ha la fondamentale capacità di rendere la *distribuzione trasparente*

==== Trasparenza
Proprio questo concetto di *trasparenza* è fondamentale da approfondire. In generale per un utente non dovrebbe essere rilevante come internamente il DBMS gestisce lo storage dei dati e l'esecuzione di query. Esistono diverse tipologie di trasparenza:

- *Access Transparency*: l'accesso ai dati è indipendente dalla struttura della rete o dall'organizzazione fisica dei dati.
- *Location Transparency*: gli utenti non devono conoscere come i dati sono distribuiti.
- *Replication Transparency*: gli utenti non devono conoscere se stanno accedendo a dati replicati o meno.
- *Fragmentation Transparency*: la frammentazione e lo sharding sono tipicamente gestiti internamente. Un utente dovrebbe poter effettuare query alla base di dati come se fosse un'unica entità, senza preoccuparsi di come i dati sono stati frammentati.
- *Migration Transparency*: i dati possono essere spostati tra nodi senza che gli utenti ne siano consapevoli.
- *Concurrency Transparency*: il sistema deve gestire l'accesso concorrente ai dati in modo che gli utenti non debbano preoccuparsi di conflitti o problemi di coerenza.
- *Failure Transparency*: il sistema deve essere in grado di gestire guasti dei nodi o della rete senza che gli utenti ne siano consapevoli.

#pagebreak()

== Guasti nei Sistemi Distribuiti
È importante andare a considerare come in un sistema distribuito, i guasti sono inevitabili. Esistono diverse tipologie di guasti che possono verificarsi. Lo scopo di questa sezione è quello di andare a presentarli brevemente assieme alle tecniche più comuni per mitigarli.

Il primo caso, più semplice è quello in cui a guastarsi sia un singolo nodo (server del sistema). In questo caso andremo a parlare di *server failure*. @fig:0601 mostra un'illustrazione di questo tipo di guasto.

#figure(
  image("../images/ch06/01_server_failure.png", width: 55%),
  caption: "Illustrazione di un guasto su un nodo singolo in un sistema distribuito.",
)<fig:0601>

Un'altra tipologia di guasto è quella di *network failure*, in cui la comunicazione tra nodi viene interrotta. Questo può essere causato da problemi di rete, congestione o guasti hardware. @fig:0602 mostra un'illustrazione di questo tipo di guasto.

#figure(
  image("../images/ch06/02_netfail.png", width: 45%),
  caption: "Illustrazione di un guasto di rete in un sistema distribuito.",
)<fig:0602>

Nell'eventualità in cui si verifichino *guasti multipli*, potremmo trovarci in una condizione chiamata *network partitioning*, in cui la rete di comunicazione trai server risulta divisa in più segmenti che non possono comunicare tra di loro. @fig:0603 mostra un'illustrazione di questo tipo di guasto.
#remark[
  È importante considerare che un segmento di partizionamento potrebbe essere composto anche da un singolo nodo, nel caso in cui questo risulti isolato dal resto della rete.

  Si noti come spesso e volentieri le situazioni di *network partitioning* siano estremamente difficili da distiguere rispetto a quelle di *server failure*, in quanto da un nodo potrebbe sembrare che un altro nodo sia semplicemente non raggiungibile.
]

#figure(
  image("../images/ch06/03_netpartition.png", width: 47%),
  caption: "Illustrazione di un partizionamento di rete in un sistema distribuito.",
)<fig:0603>

== Protocolli Epidemici

=== Background
Uno dei punti cruciali all'interno di un sistema distribuito è la *propagazione* delle *informazioni*. In un sistema distribuito, si tratta di un compito complesso, per due principali motivi:

- _Perdita di messaggi_: in una rete distribuita, i messaggi possono essere persi a causa di guasti di rete, congestione o altri problemi, e maggiore il numero di nodi e connessioni, maggiore è la probabilità che questo accada.
- _Forte agitazione dei nodi_: in un sistema distribuito, i nodi possono entrare e uscire dalla rete in qualsiasi momento, rendendo difficile mantenere una visione coerente dello stato del sistema.

Una delle tecniche più interessanti per mitigare questi problemi è l'utilizzo di *protocolli epidemici*, _protocolli peer to peer_ ispirati al modo in cui le infezioni o il 'gossip' si diffondono in una popolazione.
Per capire il motivo dietro al quale utilizziamo una modalità peer to peer, consideriamo il caso in cui usassimo un modello *point to point*: per utilizzare questa strategia ogni nodo dovrebbe quantomeno essere a conoscenza dell'esistenza di tutti gli altri nodi. Per garantire questo avremmo due possibilità:

- Ogni nodo mantiene una lista di tutti gli altri nodi: questo approccio non scala bene, in quanto ogni volta che un nodo entra o esce dalla rete, tutti gli altri nodi devono essere aggiornati.
- Utilizzare un nodo centrale per mantenere la lista dei nodi: questo approccio introduce un singolo punto di fallimento e può diventare un collo di bottiglia.

Il ruolo dei protocolli epidemici è dunque quello di permettere propagare le informazioni ricevute da un nodo a tutti gli altri, nel modo più efficiente possibile, e con la massima affidabilità possibile. All'interno di un protocollo epidemico, ogni nodo potrebbe trovarsi in uno dei seguenti stati:

- *Infetto*: il nodo ha ricevuto l'informazione e la sta _propagando ad altri nodi_
- *Suscettibile*: il nodo non ha ancora ricevuto l'informazione, ma è in grado di riceverla.
- *Rimosso*: il nodo ha ricevuto l'informazione, ma non la propaga più ad altri nodi.+

Il motivo per cui un i nodi possono essere infetti o suscettibli appare abbastanza chiaro: senza nodi suscettibili, l'informazione non si potrebbe propagare, e in modo analogo senza nodi infetti, non ci sarebbe nessuno a propagarla. Per quanto riguarda lo stato di *rimosso* invece, questo viene introdotto per evitare che l'informazione venga propagata all'infinito. Per fare questo i nodi infetti possono decidere di diventare rimossi dopo un certo periodo di tempo, o dopo aver propagato l'informazione ad un certo numero di nodi.

=== Varianti di Protocolli Epidemici
Esistono diverse varianti di protocolli epidemici, ognuna con le proprie caratteristiche e vantaggi. Di seguito andiamo a presentarne alcune.

==== Variante Anti-Entropica
Un approccio di tipo *anti-entropico* è trai più semplici che si possono applicare. Ogni nodo in questo protocollo può essere soltanto *infetto* o *suscettibile*. I nodi infetti _periodicamente_ propagano l'informazione ai loro nodi vicini suscettibili. Questo processo continua fino a quando tutti i nodi sono stati infettati.

Il problema maggiore di questo approccio consiste nell'*eccessivo utilizzo di banda* e che ad ogni round, ogni nodo controlla che i suoi vicini siano suscettibili a nuove informazioni.

==== Approccio Rumor Spreading
La propagazione delle informazione viene avviata solamente nel momento in cui un nodo riceve *nuova informazione* o può essere attivata in maniera *periodica*. La differenza rispetto a prima è che in questo caso le dinamiche di propagazione sono differenti:

- La quantità di nodi infetti viene fatta decrescere nel tempo mano a mano che il numero di nodi *rimossi* aumenta
- Ogni server può passare da *infetto* a *rimosso* sulla base di alcune euristiche, per esempio con una certa probabilità ad ogni round, o dopo aver inviato l'informazione ad un certo numero di nodi.

=== Hash Trees
Come già anticipato, è necessario garantire che ogni coppia di nodi possa stabilire quali informazioni sono rispettivamente note ad ognuno. Per questa operazione si potrebbe pensare di applicare una semplice operazione di *differenza insiemistica*. Tuttavia un'operazione di questo tipo potrebbe risultare inefficiente, richiedendo un numero di operazioni pari ad $O(n)$, dove $n$ è il numero di elementi da confrontare. Per ovviare a questo problema, si può utilizzare una struttura dati chiamata *hash tree* (o *merkle tree*).

Un *hash tree* può essere visto come un *indice* gerarchico di hash. Ogni nodo foglia dell'albero rappresenta un blocco di dati, e ogni nodo interno rappresenta l'hash dei suoi nodi figli. In questo modo, ogni nodo può rappresentare un insieme di dati tramite un singolo hash. Questo permette di confrontare rapidamente grandi insiemi di dati. @fig:06_merkletree ne mostra un esempio.

#figure(
  image("../images/ch06/04_merkletree.png", width: 80%),
  caption: "Esempio di Hash Tree con 8 nodi foglia data una lista di messaggi A,B,C,D,E,F,G,H.",
)<fig:06_merkletree>

Nel caso in cui tutti i messaggi ricevuti da due nodi siano gli stessi, anche gli hash dei nodi radice saranno gli stessi. In caso contrario, i nodi possono scendere lungo l'albero confrontando gli hash dei nodi figli per identificare quali blocchi dati differiscono.

#remark[Chiaramente l'utilizzo di una struttura come gli Hash Tree implica che tutti i nodi della rete devono concordare sull'ordinamento dei messaggi che pervengono e su una funzione di hashing univoca.]

== Frammentazione ("Sharding")
Una delle tecniche più comuni per la gestione di dati grandi e massivi è quella di ricorrere alla *frammentazione* degli stessi. L'idea è quella di suddividere appunto grandi quantità di dati in *frammenti più piccoli* che possano essere gestiti in maniera più agile. Di seguito presentiamo vantaggi e svantaggi di questa tecnica.

- *Località dei dati*: possiamo delegare ad un nodo locale la gestione e la computazione di operazioni su un frammento di dati comunicando il risultato finale agli altri nodi #emoji.checkmark.box
- *Riduzione dei costi di comunicazione*: svolgendo le operazioni a livello di singolo frammento in locale, è possibile ridurre la quantità di dati che deve essere trasferita nella rete #emoji.checkmark.box
- *Performance migliorate*: operazioni su frammenti più piccoli di dati tendono ad essere più veloci rispetto a operazioni su grandi insiemi di dati #emoji.checkmark.box
- *Indici più efficienti*: gli indici possono essere creati e mantenuti più facilmente su frammenti più piccoli di dati #emoji.checkmark.box
- Possibilità di applicare *load balancing*: distribuendo i frammenti di dati tra diversi nodi, è possibile bilanciare il carico di lavoro e migliorare le prestazioni complessive del sistema #emoji.checkmark.box
- *Query più complesse*: le query che coinvolgono più frammenti di dati possono diventare più complesse da gestire e ottimizzare #emoji.crossmark
- *Gestione più complessa*: operazioni di backup e recovery possono diventare più complesse in un sistema frammentato #emoji.crossmark
