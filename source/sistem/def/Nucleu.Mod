(* Nucleu: apelurile de sistem ale Eulei, singurul loc unde Oberon atinge Java.
   Biblioteca de module: ce compilezi ramane si poate fi importat sau chemat ca Modul.Comanda.
   Implementat in Java (sistem/java/Nucleu.java). *)
DEFINITION Nucleu;
  PROCEDURE Compileaza(fisier: ARRAY OF CHAR): BOOLEAN;  (* modulele din fisier intra in biblioteca *)
  PROCEDURE Ruleaza(fisier: ARRAY OF CHAR): BOOLEAN;     (* compileaza si porneste ultimul modul, de la zero *)
  PROCEDURE Cheama(modul, comanda: ARRAY OF CHAR): INTEGER;  (* 0 bine, 1 nu e modul, 2 nu e comanda, 3 s-a oprit *)
  PROCEDURE Module(): INTEGER;                           (* cate module are sistemul; apoi Modul(i) *)
  PROCEDURE Modul(i: INTEGER; VAR nume: ARRAY OF CHAR);
  PROCEDURE DinBiblioteca(i: INTEGER): BOOLEAN;          (* modulul i e scris de tine (nu de sistem)? *)
  PROCEDURE Comenzi(modul: ARRAY OF CHAR): INTEGER;      (* procedurile exportate fara parametri; apoi Comanda(i) *)
  PROCEDURE Comanda(i: INTEGER; VAR nume: ARRAY OF CHAR);
  PROCEDURE Uita(modul: ARRAY OF CHAR): BOOLEAN;         (* scoate modulul din biblioteca *)
  PROCEDURE Eroare(VAR s: ARRAY OF CHAR);
  PROCEDURE Terminal(cerere: ARRAY OF CHAR);             (* cereri catre ecran: "edit;cale", "eula", "inferno;charon URL" *)
  PROCEDURE Sh(comanda: ARRAY OF CHAR): INTEGER;         (* shell-ul Android; "" = interactiv *)
  PROCEDURE Inferno(comanda: ARRAY OF CHAR): INTEGER;    (* sh-ul lui Inferno in terminal; "" = interactiv *)
  PROCEDURE Timp(): INTEGER;                             (* milisecunde *)
  PROCEDURE Asteapta(ms: INTEGER);                       (* pauza *)
  PROCEDURE Oprit(): BOOLEAN;                            (* ai apasat Ctrl+C? (buclele lungi il pot asculta) *)
  PROCEDURE Opreste(cod: INTEGER);
END Nucleu.
