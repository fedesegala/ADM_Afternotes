#import "@preview/theorion:0.4.0": *
#import cosmos.fancy: *
#show: show-theorion
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *
#show: codly-init.with()
#import "../lib.typ": *

#import "@preview/headcount:0.1.0": dependent-numbering, reset-counter

#set figure(numbering: dependent-numbering("1.1"))
#show heading: reset-counter(counter(figure.where(kind: image)))

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
In questa sezione andremo a vedere più nel dettaglio, dato il modello logico precedentemente descritto, come i dati vengano effettivamente memorizzati sul dico
