(* Dosar: fisierele si dosarele telefonului (in casa Eulei). Caile relative pornesc din dosarul curent.
   Implementat in Java (sistem/java/Dosar.java). Pentru continutul fisierelor: modulul Files. *)
DEFINITION Dosar;
  PROCEDURE Acasa(VAR s: ARRAY OF CHAR);
  PROCEDURE Curent(VAR s: ARRAY OF CHAR);
  PROCEDURE Schimba(cale: ARRAY OF CHAR): BOOLEAN;
  PROCEDURE Cale(nume: ARRAY OF CHAR; VAR abs: ARRAY OF CHAR);  (* calea intreaga *)
  PROCEDURE Exista(cale: ARRAY OF CHAR): BOOLEAN;
  PROCEDURE EsteDosar(cale: ARRAY OF CHAR): BOOLEAN;
  PROCEDURE Marime(cale: ARRAY OF CHAR): INTEGER;
  PROCEDURE Lista(cale: ARRAY OF CHAR): INTEGER;    (* cate intrari; -1 daca nu e dosar; apoi Nume(i) *)
  PROCEDURE Nume(i: INTEGER; VAR s: ARRAY OF CHAR);
  PROCEDURE Creeaza(cale: ARRAY OF CHAR): BOOLEAN;  (* dosar nou, cu tot cu parintii *)
  PROCEDURE Sterge(cale: ARRAY OF CHAR): BOOLEAN;   (* fisier sau dosar gol *)
  PROCEDURE Muta(din, spre: ARRAY OF CHAR): BOOLEAN;
  PROCEDURE Copiaza(din, spre: ARRAY OF CHAR): BOOLEAN;
END Dosar.
