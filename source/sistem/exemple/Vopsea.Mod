MODULE Vopsea;  (* o comanda: Vopsea.Litri lungime inaltime *)
  IMPORT Out, Param;

  PROCEDURE Litri*;
    VAR l, h: INTEGER;
  BEGIN
    l := Param.Int(0); h := Param.Int(1);
    Out.String("Litri: "); Out.Int(l * h DIV 10, 0); Out.Ln
  END Litri;

END Vopsea.
