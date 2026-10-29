(* Retea: internetul. Implementat in Java (sistem/java/Retea.java). *)
DEFINITION Retea;
  PROCEDURE Descarca(url, fisier: ARRAY OF CHAR): INTEGER;  (* octetii primiti; negativ = eroare *)
  PROCEDURE Eroare(VAR s: ARRAY OF CHAR);                   (* ce n-a mers la ultima descarcare *)
END Retea.
