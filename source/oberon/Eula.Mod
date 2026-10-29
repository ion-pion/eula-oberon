MODULE Eula; (* Eula Oberon: usa spre pielea de Java. Pielea deseneaza ecranul si citeste fisierele; tot ce inseamna
  ceva — gramatica, memoria, sorobanul, Opal, Roler, firea — e in modulele Oberon de mai jos.
  Raspunsul se citeste din Iesire.r, nota de sub raspuns din Motor.nota, linia de stare din Eula.stare. *)

  IMPORT Litere, Iesire, Memorie, Motor, Fire, Lectii;

  VAR stare*: ARRAY 256 OF CHAR;
    dosar: ARRAY 1024 OF CHAR;

  PROCEDURE Cale(nume: ARRAY OF CHAR; VAR d: ARRAY OF CHAR);
  BEGIN Litere.Copy(dosar, d); Litere.Add(d, "/"); Litere.Add(d, nume)
  END Cale;

  PROCEDURE Stare*;
  BEGIN stare := ""; Iesire.CateIn(stare, Memorie.NrModule(), "modul", "module"); Litere.Add(stare, " · ");
    Iesire.CateIn(stare, Memorie.NrProceduri(), "procedură", "proceduri")
  END Stare;

  (* dir = dosarul aplicatiei (getFilesDir) *)
  PROCEDURE Porneste*(dir: ARRAY OF CHAR);
    VAR f, v: ARRAY 1100 OF CHAR;
  BEGIN Litere.Copy(dir, dosar); Cale("fire-oberon.bin", f); Cale("fire.txt", v); Fire.Incarca(f, v);
    Cale("lectii.bin", f); Lectii.Incarca(f)
  END Porneste;

  PROCEDURE Salut*;
  BEGIN Iesire.Gol;
    Iesire.S("Salut! Sunt Eula Oberon și știu doar Oberon — iar acum sunt scrisă chiar în Oberon. Întreabă-mă „ce face Texts.WriteString?”, ");
    Iesire.S("„cum folosesc Files.Old?”, „regula IfStatement” — sau lipește cod și apasă Verifică ori Rulează. Dacă vrei să înveți Oberon de la zero, scrie „lecții”. ");
    Iesire.S("Scrie „?” pentru tot ce știu să fac.")
  END Salut;

  PROCEDURE IncarcaFoto*(cale, cheie: ARRAY OF CHAR): BOOLEAN;
    VAR ok: BOOLEAN;
  BEGIN ok := Memorie.Incarca(cale, cheie); Stare;
    RETURN ok
  END IncarcaFoto;

  PROCEDURE SalveazaFoto*(cale, cheie: ARRAY OF CHAR): BOOLEAN;
  BEGIN RETURN Memorie.Salveaza(cale, cheie)
  END SalveazaFoto;

  PROCEDURE Goleste*;
  BEGIN Memorie.Goleste; Stare
  END Goleste;

  PROCEDURE Mananca*(VAR t: ARRAY OF CHAR; n: INTEGER; src: ARRAY OF CHAR): INTEGER;
    VAR k: INTEGER;
  BEGIN k := Memorie.Adauga(t, n, src); Stare;
    RETURN k
  END Mananca;

  (* ce spune dupa ce a mancat ultima bucata *)
  PROCEDURE Mancat*(k: INTEGER);
    VAR r: INTEGER; m, d, e: ARRAY 700 OF CHAR;
  BEGIN Iesire.Gol; r := Memorie.nrec - 1;
    Memorie.ModIn(r, m); Memorie.DialIn(r, d); IF Memorie.recErrN[r] > 0 THEN Memorie.ErrIn(r, e) ELSE e := "" END ;
    IF m[0] # 0X THEN
      Iesire.S("Am mâncat modulul "); Iesire.S(m); Iesire.S(" ("); Iesire.S(d); Iesire.S(", "); Iesire.Cate(k, "unitate", "unități"); Iesire.S(").");
      IF e[0] # 0X THEN Iesire.S(" Are o greșeală la "); Iesire.S(e); Iesire.S("; l-am ținut minte oricum.") END
    ELSIF d = "text" THEN Iesire.S("Am ținut minte ("); Iesire.Cate(k, "bucată", "bucăți"); Iesire.S(" de text).")
    ELSE Iesire.S("Am ținut minte fragmentul de cod ("); Iesire.S(d); Iesire.S(").");
      IF e[0] # 0X THEN Iesire.S(" Greșeală la "); Iesire.S(e); Iesire.S(".") END
    END
  END Mancat;

  PROCEDURE PareCod*(VAR t: ARRAY OF CHAR; n: INTEGER): BOOLEAN;
  BEGIN RETURN Memorie.PareCod(t, n)
  END PareCod;

  (* intrebarea; intoarce 3 cand e o fraza „X este …” de tinut minte (pielea o scrie in memorie, apoi cheama Invatat) *)
  PROCEDURE Intreaba*(q: ARRAY OF CHAR): INTEGER;
    VAR r: INTEGER;
  BEGIN Iesire.Gol; Motor.GolNota;
    IF Lectii.Comanda(q) THEN r := 1 ELSE r := Fire.Raspunde(q) END ;
    IF r = 0 THEN Motor.Raspunde(q)
    ELSIF r = 2 THEN Iesire.S(" "); Motor.Raspunde(Fire.rest)
    END ;
    IF (r = 0) OR (r = 2) THEN Fire.Socoteste END ;
    RETURN r
  END Intreaba;

  PROCEDURE SursaInvatat*(VAR d: ARRAY OF CHAR);
  BEGIN d := "învățat de la "; IF Fire.areNume THEN Litere.Add(d, Fire.nume) ELSE Litere.Add(d, "Pion") END
  END SursaInvatat;

  PROCEDURE Invatat*(q: ARRAY OF CHAR);
  BEGIN Iesire.Gol; Motor.GolNota; Fire.AInvatat(q)
  END Invatat;

  PROCEDURE Verifica*(VAR t: ARRAY OF CHAR; n: INTEGER);
  BEGIN Motor.Verifica(t, n); Lectii.DupaVerificare(t, n); Fire.Verificat
  END Verifica;

BEGIN dosar := "."; stare := ""
END Eula.
