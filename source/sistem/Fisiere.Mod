MODULE Fisiere;  (* comenzile pentru fisiere: ls cd pwd cat cp mv rm mkdir edit (vezi Shell pentru nume scurte) *)
  IMPORT Out, Files, Strings, Param, Dosar, Nucleu;

  CONST N = 1024;

  PROCEDURE Lista*;   (* ls [dosar]: ce e in dosar; dosarele au / la coada *)
    VAR d, nume, cale: ARRAY N OF CHAR; n, i: INTEGER;
  BEGIN
    IF Param.Nr() > 0 THEN Param.Str(0, d) ELSE d := "" END;
    n := Dosar.Lista(d);
    IF n < 0 THEN Out.String("nu e dosar: "); Out.String(d); Out.Ln
    ELSIF n = 0 THEN Out.String("(gol)"); Out.Ln
    ELSE
      FOR i := 0 TO n - 1 DO
        Dosar.Nume(i, nume);
        cale := d;
        IF cale # "" THEN Strings.Append("/", cale) END;
        Strings.Append(nume, cale);
        Out.String(nume);
        IF Dosar.EsteDosar(cale) THEN Out.String("/")
        ELSE Out.String("  "); Out.Int(Dosar.Marime(cale), 0)
        END;
        Out.Ln
      END
    END
  END Lista;

  PROCEDURE Unde*;   (* pwd: dosarul curent *)
    VAR s: ARRAY N OF CHAR;
  BEGIN Dosar.Curent(s); Out.String(s); Out.Ln
  END Unde;

  PROCEDURE Schimba*;   (* cd [dosar]: fara dosar te duce acasa *)
    VAR s: ARRAY N OF CHAR;
  BEGIN
    IF Param.Nr() > 0 THEN Param.Str(0, s) ELSE s := "" END;
    IF ~Dosar.Schimba(s) THEN Out.String("nu e dosar: "); Out.String(s); Out.Ln END
  END Schimba;

  PROCEDURE Arata*;   (* cat fisier...: arata ce scrie in fisiere *)
    VAR nume, cale: ARRAY N OF CHAR; i: INTEGER; f: Files.File; c: CHAR;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: cat Fisier"); Out.Ln END;
    FOR i := 0 TO Param.Nr() - 1 DO
      Param.Str(i, nume); Dosar.Cale(nume, cale);
      IF ~Dosar.Exista(cale) OR Dosar.EsteDosar(cale) THEN Out.String("nu e fisier: "); Out.String(nume); Out.Ln
      ELSE
        f := Files.Open(cale);
        IF f = NIL THEN Out.String("nu pot deschide "); Out.String(nume); Out.Ln
        ELSE
          c := Files.ReadChar(f);
          WHILE Files.Status(f) = Files.OK DO Out.Char(c); c := Files.ReadChar(f) END;
          Files.Close(f)
        END
      END
    END
  END Arata;

  PROCEDURE Doi(VAR a, b: ARRAY OF CHAR; folosire: ARRAY OF CHAR): BOOLEAN;
    VAR ok: BOOLEAN;
  BEGIN
    ok := Param.Nr() = 2;
    IF ok THEN Param.Str(0, a); Param.Str(1, b) ELSE Out.String("folosire: "); Out.String(folosire); Out.Ln END
    RETURN ok
  END Doi;

  PROCEDURE Copiaza*;   (* cp din spre *)
    VAR a, b: ARRAY N OF CHAR;
  BEGIN
    IF Doi(a, b, "cp din spre") & ~Dosar.Copiaza(a, b) THEN Out.String("n-am putut copia "); Out.String(a); Out.Ln END
  END Copiaza;

  PROCEDURE Muta*;   (* mv din spre: muta sau redenumeste *)
    VAR a, b: ARRAY N OF CHAR;
  BEGIN
    IF Doi(a, b, "mv din spre") & ~Dosar.Muta(a, b) THEN Out.String("n-am putut muta "); Out.String(a); Out.Ln END
  END Muta;

  PROCEDURE Sterge*;   (* rm fisier...: sterge fisiere sau dosare goale *)
    VAR s: ARRAY N OF CHAR; i: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: rm Fisier"); Out.Ln END;
    FOR i := 0 TO Param.Nr() - 1 DO
      Param.Str(i, s);
      IF ~Dosar.Sterge(s) THEN Out.String("n-am putut sterge "); Out.String(s); Out.Ln END
    END
  END Sterge;

  PROCEDURE Creeaza*;   (* mkdir dosar...: dosare noi *)
    VAR s: ARRAY N OF CHAR; i: INTEGER;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: mkdir Dosar"); Out.Ln END;
    FOR i := 0 TO Param.Nr() - 1 DO
      Param.Str(i, s);
      IF ~Dosar.Creeaza(s) THEN Out.String("n-am putut crea "); Out.String(s); Out.Ln END
    END
  END Creeaza;

  PROCEDURE Edit*;   (* edit fisier: editorul violet-auriu al Eulei *)
    VAR s, cale, cerere: ARRAY N OF CHAR;
  BEGIN
    IF Param.Nr() = 0 THEN Out.String("folosire: edit Fisier.Mod"); Out.Ln
    ELSE
      Param.Str(0, s); Dosar.Cale(s, cale);
      cerere := "edit;"; Strings.Append(cale, cerere);
      Nucleu.Terminal(cerere)
    END
  END Edit;

END Fisiere.
