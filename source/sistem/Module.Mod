MODULE Module;  (* biblioteca de module: compileaza, ruleaza, module, comenzi, uita *)
  IMPORT Out, Param, Nucleu;

  CONST N = 1024;

  PROCEDURE Compileaza*;   (* compileaza Fisier.Mod...: modulele intra in biblioteca, comenzile lor pot fi chemate *)
    VAR f: ARRAY N OF CHAR; i: INTEGER; ok: BOOLEAN;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: compileaza Fisier.Mod"); Out.Ln
    ELSE
      i := 0; ok := TRUE;
      WHILE ok & (i < Param.Nr()) DO Param.Str(i, f); ok := Nucleu.Compileaza(f); INC(i) END
    END
  END Compileaza;

  PROCEDURE Ruleaza*;   (* ruleaza Fisier.Mod: compileaza si porneste programul (corpul ultimului modul) *)
    VAR f: ARRAY N OF CHAR;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: ruleaza Fisier.Mod"); Out.Ln
    ELSE Param.Str(0, f);
      IF ~Nucleu.Ruleaza(f) THEN (* Nucleu a spus deja de ce *) END
    END
  END Ruleaza;

  PROCEDURE ArataComenzi(VAR m: ARRAY OF CHAR);
    VAR c: ARRAY 64 OF CHAR; k, j: INTEGER;
  BEGIN
    k := Nucleu.Comenzi(m);
    IF k < 0 THEN Out.String("nu am modulul "); Out.String(m)
    ELSIF k = 0 THEN Out.String(m); Out.String(": (nicio comanda)")
    ELSE
      Out.String(m); Out.String(":");
      FOR j := 0 TO k - 1 DO Nucleu.Comanda(j, c); Out.String(" "); Out.String(c) END
    END;
    Out.Ln
  END ArataComenzi;

  PROCEDURE Lista*;   (* module: ce module are sistemul si ce module ai scris tu *)
    VAR m: ARRAY 64 OF CHAR; n, i, ale: INTEGER;
  BEGIN
    n := Nucleu.Module(); ale := 0;
    Out.String("Ale sistemului:");
    FOR i := 0 TO n - 1 DO
      IF ~Nucleu.DinBiblioteca(i) THEN Nucleu.Modul(i, m); Out.String(" "); Out.String(m) ELSE INC(ale) END
    END;
    Out.Ln;
    IF ale = 0 THEN Out.String("Ale tale: inca niciunul (compileaza Fisier.Mod)"); Out.Ln
    ELSE
      Out.String("Ale tale:"); Out.Ln;
      FOR i := 0 TO n - 1 DO
        IF Nucleu.DinBiblioteca(i) THEN Nucleu.Modul(i, m); Out.String("  "); ArataComenzi(m) END
      END
    END
  END Lista;

  PROCEDURE Comenzi*;   (* comenzi [Modul...]: comenzile unui modul (fara modul: ale tuturor) *)
    VAR m: ARRAY 64 OF CHAR; n, i: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN
      n := Nucleu.Module();
      FOR i := 0 TO n - 1 DO Nucleu.Modul(i, m); ArataComenzi(m) END
    ELSE
      FOR i := 0 TO Param.Nr() - 1 DO Param.Str(i, m); ArataComenzi(m) END
    END
  END Comenzi;

  PROCEDURE Uita*;   (* uita Modul: scoate un modul al tau din biblioteca *)
    VAR m: ARRAY 64 OF CHAR; i: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: uita Modul"); Out.Ln END;
    FOR i := 0 TO Param.Nr() - 1 DO
      Param.Str(i, m);
      IF Nucleu.Uita(m) THEN Out.String("am uitat "); Out.String(m) ELSE Out.String("nu e in biblioteca: "); Out.String(m) END;
      Out.Ln
    END
  END Uita;

END Module.
