= Column Stores
Fino a questo momento abbiamo di varie tipologie di basi, ovvero modelli relazionali, key-value stores e document stores. Tra queste tipologie i modello NoSQL si rendono necessari nel momento in cui non serve più garantire le proprietà ACID, ma si preferisce garantire efficienza e velocità di accesso ai dati. 

In tutti i precedenti capitoli è sempre stata discussa la *modalità di interazione* con il *data model* per ognuna delle categorie viste ma non è mai stato mostrato *come* i dati vengano effettivamente memorizzati all'interno dei database. 

Prima di introdurre i *column stores* è necessario fare una breve digressione dove andremo a vedere come i dati vengono memorizzati all'interno dei database relazionali, useremo i database relazionali dal momento che sono quelli con la quale la maggior parte ha familiarità. Tutto questo verrà ulteriormente approfondito in uno dei successivi capitoli. 

== Architettura di un R-DBMS

#figure(
    image("../images/rdbms_internal.png", width: 90%), 
    caption: "Organizzazione interna delle componenti di un R-DBMS",
)<fig:rdbms_internal>

Quello che vediamo in @fig:rdbms_internal è una rappresentazione dell'organizzazione interna delle componenti di un DBMS relazionale. Ciò che è importante notare è che possiamo disinguere due macro aree: 

- La parte superiore dell'immagine rappresenta la parte logica del database, anche detta *relational engine*, la quale si occupa di gestire le query, l'ottimizzazione delle stesse e la gestione delle transazioni e accede alla parte inferiore tramite delle API
- La parte inferiore dell'immagine rappresenta la parte fisica del database, anche detta *storage engine*, la quale si occupa di gestire l'effettiva memorizzazione dei dati

Possiamo notare come la gestione delle transazioni sia demandata alla parte dello storage engine, il quale è l'unico componente che ha accesso diretto al file system. Ciò che è importante per questo capitolo è comprendere il funzionamento delle seguenti componenti: 

- *Storage structures manager*
- *Buffer manager*
- *Persistent memory manager*

Andremo ad analizzare il funzionamento di queste componenti nelle sezioni successive. 

=== Persistent Memory Manager
La componente del *persistent memory manager* si occupa di *astrarre* i dispositivi fisici di memorizzazione fornendone una *vista logica*. Tipicamente la memoria che viene gestita si può vedere costituita di due livelli: 

- *Memoria principale* (RAM), che è molto veloce (10-100ns), piccola (nell'ordine dei GigaByte), volatile e molto costosa
- *Memoria secondaria* (Dischi), che è al contrario permanente, di più grande capacità (svariati TeraByte) ed economica ma molto più lenta (5-10ms). 