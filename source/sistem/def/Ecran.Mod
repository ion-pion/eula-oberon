(* Ecran: desenul aplicatiilor facute cu Aplicatie.Fa. Merge doar intr-o aplicatie (nu in terminal).
   Aplicatia exporta Deseneaza* (chemata la fiecare cadru) si, daca vrea, Atinge* (la atingere).
   Implementat in Java (aplicatie/java/Ecran.java). *)
DEFINITION Ecran;
  PROCEDURE Latime(): INTEGER;
  PROCEDURE Inaltime(): INTEGER;
  PROCEDURE Densitate(): INTEGER;                 (* 100 = 1 pixel pe dp; de obicei 250..450 pe telefon *)
  PROCEDURE RGB(r, g, b: INTEGER): INTEGER;        (* o culoare *)
  PROCEDURE Fond(culoare: INTEGER);                (* umple tot ecranul *)
  PROCEDURE Culoare(culoare: INTEGER);
  PROCEDURE Grosime(pixeli: INTEGER);
  PROCEDURE Linie(x0, y0, x1, y1: INTEGER);
  PROCEDURE Cerc(x, y, raza: INTEGER);
  PROCEDURE Disc(x, y, raza: INTEGER);
  PROCEDURE Dreptunghi(x, y, latime, inaltime: INTEGER);
  PROCEDURE Triunghi(x0, y0, x1, y1, x2, y2: INTEGER);
  PROCEDURE Text(x, y, marime: INTEGER; s: ARRAY OF CHAR);   (* centrat pe x; y = linia de baza *)
  PROCEDURE AtinsX(): INTEGER;
  PROCEDURE AtinsY(): INTEGER;
  PROCEDURE Apasat(): BOOLEAN;
  PROCEDURE Tastatura(da: BOOLEAN);                (* v24: arata / ascunde tastatura; cand apare, Inaltime scade *)
  PROCEDURE Tasta(): INTEGER;                      (* v24: urmatoarea litera scrisa: 0 = nimic, 13 = Enter, 8 = sterge *)
  PROCEDURE Lanseaza(tinta: ARRAY OF CHAR): BOOLEAN;   (* v24: porneste alta aplicatie: "pachet" sau "Eticheta";
                                                     mai multe cu |, prima care exista. FALSE = nu e instalata *)
  (* v25: fisierele telefonului *)
  PROCEDURE AlegeFisier;                           (* alegatorul de fisiere al telefonului: alegi unul sau mai multe;
                                                     fara nicio voie ceruta. Apoi, la cadrele urmatoare, Ales *)
  PROCEDURE Ales(VAR cale, nume: ARRAY OF CHAR): BOOLEAN;   (* urmatorul fisier ales: copia lui in dosarul aplicatiei
                                                     (cale; o stergi tu cand ai terminat) si numele lui; FALSE = nimic nou *)
  PROCEDURE Descarcari(VAR d: ARRAY OF CHAR): BOOLEAN;   (* dosarul Download, daca am voie; altfel cere voie si da FALSE *)
  PROCEDURE Intrari(dosar: ARRAY OF CHAR): INTEGER;   (* cate intrari are dosarul, in ordinea numelor; -1 = nu pot citi *)
  PROCEDURE Intrare(i: INTEGER; VAR nume: ARRAY OF CHAR): INTEGER;   (* numele intrarii i din ultimul Intrari si marimea
                                                     in octeti; -1 = e dosar *)
  PROCEDURE Schimbat(i: INTEGER): INTEGER;         (* v26: cand a fost schimbata intrarea i din ultimul Intrari:
                                                     secunde de la 1 ianuarie 2010 (UTC), ca Os.CurrentTime *)
  (* v27: un socket TCP doar pe 127.0.0.1 (din telefon, nu din retea); un client odata. Daca modulul tau exporta
     Retea* (fara parametri), lansatorul o cheama cand sosesc octeti, si cand aplicatia e in spate; Retea, Deseneaza
     si Atinge nu ruleaza niciodata deodata. v28: cat asculta, aplicatia tine o notificare (ca Android sa n-o
     inghete in spate). *)
  PROCEDURE Asculta(port: INTEGER): BOOLEAN;       (* asculta pe 127.0.0.1:port; TRUE = merge *)
  PROCEDURE Primeste(VAR b: ARRAY OF BYTE): INTEGER;   (* octetii sositi (cat incap in b); 0 = nimic; -1 = clientul a plecat *)
  PROCEDURE Trimite(VAR b: ARRAY OF BYTE; n: INTEGER);   (* trimite primii n octeti clientului *)
  PROCEDURE Legat(): BOOLEAN;                      (* e un client legat acum *)
  PROCEDURE Inchide;                               (* nu mai asculta (si inchide clientul) *)
  (* v31: acelasi server, dar pe toata reteaua locala (alt telefon din Wi-Fi se poate lega); fara parola: porneste-l
     doar cand vrei. Si un client, ca aplicatia ta sa se lege ea de alt server; nu opreste ecranul cat se leaga. *)
  PROCEDURE AscultaRetea(port: INTEGER): BOOLEAN;  (* ca Asculta, dar pe toate adresele telefonului *)
  PROCEDURE AdresaMea(VAR s: ARRAY OF CHAR): BOOLEAN;   (* adresa telefonului in reteaua locala, ex. 192.168.1.20 *)
  PROCEDURE Leaga(gazda: ARRAY OF CHAR; port: INTEGER): BOOLEAN;   (* porneste legarea (in spate); TRUE = a pornit *)
  PROCEDURE Legatura(): INTEGER;                   (* 0 nimic, 1 se leaga, 2 legat, -1 n-a mers sau s-a rupt *)
  PROCEDURE Spre(VAR b: ARRAY OF BYTE; n: INTEGER);   (* trimite primii n octeti serverului *)
  PROCEDURE Dinspre(VAR b: ARRAY OF BYTE): INTEGER;   (* octetii veniti de la server; 0 = nimic; -1 = s-a rupt *)
  PROCEDURE Dezleaga;                              (* inchide legatura catre server *)
  (* v32: internetul (https) pentru aplicatiile pe panza: o adresa adusa in spate, intr-un fisier, ca text UTF-8
     (prin Android, ca Conversatie.Aduce); ecranul nu sta cat vine. *)
  PROCEDURE Aduce(adresa, cale: ARRAY OF CHAR): BOOLEAN;   (* porneste aducerea; FALSE = alta e inca in curs *)
  PROCEDURE Adus(): INTEGER;                       (* 0 = inca vine (sau nimic); cand a terminat, o data: codul HTTP
                                                     (200 = bine), -1 = fara retea *)
  (* v33: treaz si cu ecranul stins. Daca modulul tau exporta Fundal* (fara parametri), lansatorul o cheama de ~10 ori
     pe secunda cat aplicatia NU e pe ecran (in spate, ecran stins); niciodata deodata cu Deseneaza / Atinge / Retea.
     In Fundal nu se deseneaza. Ca Android sa nu opreasca aplicatia in spate, cere Treaz(TRUE, ...). *)
  PROCEDURE Treaz(da: BOOLEAN; text: ARRAY OF CHAR);   (* serviciu cu notificare + procesorul pornit; FALSE = gata *)
  PROCEDURE Anunta(titlu, text: ARRAY OF CHAR);    (* o notificare pe telefon; atingerea ei deschide aplicatia *)
  PROCEDURE Copiaza(s: ARRAY OF CHAR);             (* pune s in clipboard (din Deseneaza / Atinge) *)
  PROCEDURE Lipeste(VAR s: ARRAY OF CHAR): BOOLEAN;   (* textul din clipboard; FALSE = gol (din Deseneaza / Atinge) *)
END Ecran.
