(* Param: parametrii comenzii, adica textul scris dupa Modul.Comanda.
   Ca Oberon.Par din sistemul lui Wirth, dar cuvant cu cuvant. Implementat in Java (sistem/java/Param.java). *)
DEFINITION Param;
  PROCEDURE Seteaza(text: ARRAY OF CHAR);         (* shell-ul pune aici ce e dupa comanda *)
  PROCEDURE Nr(): INTEGER;                        (* cate cuvinte *)
  PROCEDURE Str(i: INTEGER; VAR s: ARRAY OF CHAR); (* cuvantul i (de la 0); "intre ghilimele" = un cuvant *)
  PROCEDURE Int(i: INTEGER): INTEGER;              (* cuvantul i ca numar (0 daca nu e numar) *)
  PROCEDURE EInt(i: INTEGER): BOOLEAN;             (* cuvantul i e un numar? *)
  PROCEDURE Tot(VAR s: ARRAY OF CHAR);             (* tot textul, asa cum l-ai scris *)
END Param.
