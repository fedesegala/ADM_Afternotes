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


= Extensible Record Stores
Nello scorso capitolo abbiamo visto come a volte un cambio di paradigma dello *storage engine* possa portare a dei grandi benefici in termini di prestazioni sfruttando la _località dei dati_. Vogliamo provare a spingere questo concetto ancora oltre, andando a considerare un particolare tipo di database NoSQL chiamato *extensible record store* (ERS).

Ipotizziamo di dover gestire una base di dati che memorizzi informazioni riguardanti delle persone, ogni persona avrà delle informazioni che sono particolarmente importanti, come ad esempio la data e il luogo di nascita, la città in cui questa ha residenza e così via. Probabilmente tante di queste informazioni saranno accedute 'assieme' (es. difficilmente avremo bisogno di sapere la data di nascita senza sapere anche il luogo di nascita).

== Modello Logico dei Dati
In questa sezione andremo a vedere come è possibile modellare i dati in un sistema di questo tipo. È importante andare a vedere le seguenti regole, che si pongono alla base del funzionamento degli extensible record store:

- Le colone sono raggruppate in insiemi detti *column families*, le quali hanno lo scopo di raggruppare le colonne che sono spesso accedute assieme
- Ogni column family deve essere creata prima che possa essere utilizzata (similmente a quanto avviene con una tabella SQL)
- All'interno di una column family è possibile aggiungere nuove colonne in maniera arbitraria, senza dover modificare uno schema predefinito
- Ogni riga di una column family può avere un insieme di colonne diverso dalle altre righe della stessa column family

#figure(
  image("../images/extensible_record_stores_terminology.png"),
  caption: [Terminologia degli Extensible Record Stores],
)<fig:ers_terminology>

@fig:ers_terminology mostra con chiarezza i vari elementi che troviamo all'interno un extensible record store: andiamo a definirli brevemente:

- Una *column family* è un insieme di colonne che sono spesso accedute assieme
- Una *row key* è l'identificativo univoco di una riga all'interno di una column family
- Un *column qualifier* è il nome di una colonna all'interno di una column family

#remark[Tipicamente i _column qualifiers_ sono dei metadati e sono *costanti*, tutta via in @fig:ers_terminology è stato scelto di utilizzare una data come qualificatore per una colonna. Questo è possibile dal momento le colonne sono arbitrarie e possono avere valori diversi per ogni riga (quindi nulli nel caso di dati non pertinenti). Il motivo per cui questo è stato fatto è che se possiamo accedere ai dati tramite nome di una colonna, è possibile accedere a tutti i prestiti di un giorno in maniera immediata. ]

Per quanto riguarda la memorizzazione, fino a questo momento ci basta sapere che data una column family, ogni row viene memorizzata in maniera consecutiva a quella precedente, questo consente di ottenere *località spaziale*.

==== Accesso ai Valori di una Colonna
L'accesso a un valore di una colonna è possibile tramite l'utilizzo della sua *full key*:

#align(center)[
  ```<row key>:<column family>:<column qualifier>```
]

Per esempio, con riferimento all'immagine in @fig:ers_terminology, la full key `1006.BookInfo.Author` identifica in maniera univoca il valore `Brown`.

È inoltre possibile andare ad aggiungere una dimensione ulteriore, quella *temporale*, aggiungendo alla full key un _timestamp_, questo garantisce che sia possibile avere diverse versioni dello stesso dato, ad esempio per tenere traccia delle modifiche avvenute nel tempo.


== Storage Fisico dei Dati
In questa sezione andremo a vedere più nel dettaglio, dato il modello logico precedentemente descritto, come i dati vengano effettivamente memorizzati sul dico. Il principio fondamentale di questa tipologia di basi di dati è quello di consentire alta velocità in scrittura, anche al costo di avere delle letture un po' più lente.

=== Flusso delle operazioni di scrittura
Tipicamente i dati più recenti vengono scritti all'interno di una struttura chiamata *memtable* che risiede in memoria principale. Tipicamente viene mantenuta una memtable per ogni column family. Ogni record nella memtable viene identificato tramite la sua full key (`row + column family + qualifier + timestamp[ms]`).

Una volta che una memtable è completa, avviene un'operazione di *flushing*, che consiste nel salvare i dati in memoria su disco.
Potremmo tranquillamente scrivere i dati in un unico file, mettendo i dati nuovi in coda a quelli inseriti per ultimi, ma questo porterebbe a dover scorrere tutto il file per trovare un dato specifico, risultando in un costo estremamente elevato in lettura. Questo costo potrebbe essere notevolmente abbassato memorizzando i dati in maniera ordinata, ma questo, utilizzando un singolo file, comporterebbe il dover ogni volta cercare la posizione di ogni dato da scrivere e il dover spostare i dati in avanti per fare spazio a quelli nuovi, risultando in _scritture lente_.

Per mitigare il costo in lettura, viene scelto di effettuare un'operazione di *ordinamento* su ogni memtable e di memorizzare la tabella ordinata in un singolo file in memoria. Questo è il motivo per cui sostanzialmente ha senso avere una memtable per ogni column family: il fatto che l'ordinamento possa essere effettuato sulla singola column family.
In @fig:ers_write_flow è mostrato il flusso delle operazioni di scrittura in un extensible record store.

#figure(
  image("../images/ers_write.png", width: 90%),
  caption: [Flusso delle operazioni di scrittura in un Extensible Record Store],
)<fig:ers_write_flow>

#remark[Si noti come una struttura di questo genere possa essere estesa in maniera estremamente efficace ad un architettura distribuita e ad un approccio parallelizzabile, rendendo di fatto la ricerca ancora più efficiente, lasciando ogni server a lavorare sul suo o i suoi file ordinati.]

=== Modifica e Cancellazione dei Dati
Per garantire che le scritture siano il più veloci possibili, è chiaro che anche le operazioni di modifica e/o cancellazione debbano essere diverse. Sarebbe impensabile andare a cercare il record da modificare in memoria principale e cambiarlo, dal momento che questo potrebbe essere scritto in qualsiasi posto del disco.

Per questo motivo viene imposto il vincolo che i dati memorizzati siano *immutabili* e che le modifiche di un record possano soltanto essere 'simulate' andando a scrivere un nuovo record con la stessa full key e un timestamp più recente. In questo modo, quando si andrà a leggere un record, si prenderà sempre quello con il timestamp più recente, che sarà quello valido.

#remark[Questa modalità di effettuare l'aggiornamento dei dati, permette di avere senza costi aggiuntivi l'implementazione di una sorta di *versioning* dei record.]

Se per andare a *modificare* dei dati basta semplicemente scrivere un nuovo record con un nuovo timestamp, per effettuare la *cancellazione* è possibile utilizzare un meccanismo simile, andando ad aggiungere un nuovo record con la stessa full key e un timestamp più recente, ma con un particolare valore chiamato *tombstone* che indica che quel record è stato cancellato.
Di seguito andiamo ad elencare le varie caratteristiche di questi valori:

- I tombstone vanno a _mascherare_ tutti i record precedenti con la stessa full key e timestamp precedente a quello del tombstone
- Esistono diversi tipi di tombstone, a seconda del tipo di dato che si vuole cancellare:
  - si può cancellare una singola *versione* di una colonna, andando a scrivere il *timestamp* relativo alla versione che si vuole cancellare
  - è possibile cancellare l'intera *colonna* con tutte le versioni
  - è possibile andare a cancellare un'intera *column family* andando di fatto a rimuovere tutte le versioni di tutte le colonne
- Nuove versioni per una stessa chiave possono essere scritte anche dopo la cancellazione, in questo caso il nuovo record non sarà mascherato dal tombstone

=== Flusso di Lettura dei Dati
Come già anticipato, le operazioni di lettura in un sistema di questo genere sono più lente e complesse rispetto a quelle di scrittura. Questo perché i dati sono memorizzati in maniera _sparsa_ su disco, e per trovare un dato specifico potrebbe essere necessario andare a leggere più file.

In particolare, per leggere un dato specifico si rende necessario *combinare* i dati che provengono sia dalla memtable (dati più recenti) sia dai file memorizzati su disco. La versione corretta dei dati da recuperare è quella più recente, informazione che sarà accessibile tramite timestamp. @fig:ers_read_flow mostra chiaramente questo processo.

#figure(
  image("../images/ers_read.png", width: 95%),
  caption: [Flusso delle operazioni di lettura in un Extensible Record Store],
)<fig:ers_read_flow>

==== Formato dei File
Andiamo ora a concentrare l'attenzione su come i dati vengono rappresentati all'interno dei file ordinati in memoria secondaria. Iniziamo a vedere come è strutturato un *file* (struttura ordinata proveniente dal flush della memtable):

- Ogni file si può vedere come composto da molti *blocchi* (data blocks)
- Dal momento che all'interno di un file sono presenti molti blocchi viene tenuto un *indice* che consente di trovare rapidamente il blocco che contiene il dato cercato
- Insieme all'indice viene mantenuto un *trailer* che consente di memorizzare informazioni per la gestione del file, come ad esempio la posizione dell'indice stesso

#remark[Il motivo per cui  l'indice viene inserito in fondo al file, è legato al fatto che questa scelta consente una scrittura su disco più veloce: possiamo costruire l'indice man mano che scriviamo i record uno dopo l'altro, invece di dover prima leggere tutti i record da scrivere per poter inserire l'indice in testa.]

Ogni *data block* è sostanzialmente composto da una lista di *key-value* pairs. Ogni key è la full key del record (row key + column family + column qualifier + timestamp) e il value è il valore associato a quella specifica chiave. Andando più nel dettaglio, queste key-value pairs sono memorizzate assieme ad un campo *type* che ci serve a distinguere se il record è un record normale _inserimento_, una _modifica_ o una _cancellazione_ (tombstone). @fig:ers_file_format mostra la gerarchia appena descritta.

#figure(
  image("../images/ers_fileformat.png", width: 90%),
  caption: [Formato di un file in un Extensible Record Store],
)<fig:ers_file_format>

=== Ulteriori Accorgimenti
==== Write-Ahead Logging
Il sistema progettato fino a questo momento è estremamente vulnerabile nel caso di *crash improvvisi*: tutto ciò che è presente in memtable non sarebbe infatti recuperabile. Per garnatire che i dati non vadano persi in questi casi, viene utilizzata una tecnica chiamata *write-ahead logging*. Sostanzialmente ogni operazione di scrittura viene effettuata due volte: una volta su un *file di log* memorizzato su disco, e una seconda volta nella *memtable*. In questo modo, in caso di crash, è possibile recuperare tutte le operazioni di scrittura effettuate leggendo il file di log e reinserendole nella memtable. @fig:ers_writelog mostra questo processo.

#figure(
  image("../images/ers_write_log.png", width: 90%),
  caption: [Write-Ahead Logging in un Extensible Record Store],
)<fig:ers_writelog>
