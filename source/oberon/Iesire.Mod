MODULE Iesire; (* Eula Oberon: raspunsul care se scrie, bucata de cod in lucru si numerele spuse ca in romana *)
  IMPORT Litere;

  CONST Max* = 262144; C0* = 2X; C1* = 3X;

  VAR r*: ARRAY Max OF CHAR; n*: INTEGER;      (* raspunsul *)
    t*: ARRAY Max OF CHAR; tn*: INTEGER;       (* bucata de cod (sau text) in lucru *)
    u: ARRAY Max OF CHAR;

  PROCEDURE Gol*;
  BEGIN n := 0; r[0] := 0X
  END Gol;

  PROCEDURE Inapoi*(k: INTEGER);     (* sterge ce s-a scris dupa pozitia k *)
  BEGIN IF (k >= 0) & (k < n) THEN n := k; r[n] := 0X END
  END Inapoi;

  PROCEDURE C*(c: CHAR);
  BEGIN
    IF n < Max - 1 THEN r[n] := c; INC(n); r[n] := 0X END
  END C;

  PROCEDURE S*(s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO C(s[i]); INC(i) END
  END S;

  PROCEDURE Int*(x: INTEGER);
    VAR s: ARRAY 16 OF CHAR;
  BEGIN s[0] := 0X; Litere.AddInt(s, x); S(s)
  END Int;

  (* 1.234.567 *)
  PROCEDURE NrIn*(VAR d: ARRAY OF CHAR; x: INTEGER);
    VAR s: ARRAY 16 OF CHAR; i, k, a: INTEGER;
  BEGIN s[0] := 0X; Litere.AddInt(s, x); k := Litere.Len(s); a := 0;
    IF s[0] = "-" THEN Litere.AddCh(d, "-"); a := 1 END ;
    i := a;
    WHILE i < k DO
      Litere.AddCh(d, s[i]); INC(i);
      IF (i < k) & ((k - i) MOD 3 = 0) THEN Litere.AddCh(d, ".") END
    END
  END NrIn;

  PROCEDURE Nr*(x: INTEGER);
    VAR s: ARRAY 24 OF CHAR;
  BEGIN s[0] := 0X; NrIn(s, x); S(s)
  END Nr;

  (* „1 modul”, „5 module”, „20 de module” *)
  PROCEDURE CateIn*(VAR d: ARRAY OF CHAR; x: INTEGER; unu, multe: ARRAY OF CHAR);
    VAR rest: INTEGER;
  BEGIN
    IF x = 1 THEN Litere.Add(d, "1 "); Litere.Add(d, unu)
    ELSE NrIn(d, x); rest := x MOD 100;
      IF (x # 0) & ((rest = 0) OR (rest >= 20)) THEN Litere.Add(d, " de ") ELSE Litere.Add(d, " ") END ;
      Litere.Add(d, multe)
    END
  END CateIn;

  PROCEDURE Cate*(x: INTEGER; unu, multe: ARRAY OF CHAR);
    VAR s: ARRAY 200 OF CHAR;
  BEGIN s[0] := 0X; CateIn(s, x, unu, multe); S(s)
  END Cate;

  PROCEDURE OriIn*(VAR d: ARRAY OF CHAR; x: INTEGER);
  BEGIN
    IF x = 1 THEN Litere.Add(d, "o dată") ELSE Litere.Add(d, "de "); CateIn(d, x, "dată", "ori") END
  END OriIn;

  (* ---------- bucata in lucru ---------- *)

  PROCEDURE TGol*;
  BEGIN tn := 0; t[0] := 0X
  END TGol;

  PROCEDURE TC*(c: CHAR);
  BEGIN
    IF tn < Max - 1 THEN t[tn] := c; INC(tn); t[tn] := 0X END
  END TC;

  PROCEDURE TS*(s: ARRAY OF CHAR);
    VAR i: INTEGER;
  BEGIN i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO TC(s[i]); INC(i) END
  END TS;

  PROCEDURE TTrim*;   (* scoate spatiile (<= " ") de la capetele bucatii *)
    VAR a, b, i: INTEGER;
  BEGIN a := 0; b := tn;
    WHILE (a < b) & (t[a] <= " ") DO INC(a) END ;
    WHILE (b > a) & (t[b-1] <= " ") DO DEC(b) END ;
    i := 0; WHILE a < b DO t[i] := t[a]; INC(i); INC(a) END ;
    tn := i; t[i] := 0X
  END TTrim;

  (* taie(t, randuri) din Java: fara \r; daca are mai multe randuri, primele + „… (încă N rânduri)” -> u *)
  PROCEDURE Taie(randuri: INTEGER; VAR un: INTEGER);
    VAR i, linii, k: INTEGER; s: ARRAY 64 OF CHAR;
  BEGIN linii := 1; i := 0;
    WHILE i < tn DO IF t[i] = 0AX THEN INC(linii) END ; INC(i) END ;
    un := 0; i := 0;
    IF linii <= randuri THEN
      WHILE i < tn DO IF t[i] # 0DX THEN u[un] := t[i]; INC(un) END ; INC(i) END
    ELSE k := 0;
      WHILE (i < tn) & (k < randuri) DO
        IF t[i] = 0AX THEN u[un] := 0AX; INC(un); INC(k)
        ELSIF t[i] # 0DX THEN u[un] := t[i]; INC(un)
        END ;
        INC(i)
      END ;
      IF k < randuri THEN u[un] := 0AX; INC(un) END ;
      s := "  … (încă "; Litere.AddInt(s, linii - randuri); Litere.Add(s, " rânduri)");
      i := 0;
      WHILE s[i] # 0X DO u[un] := s[i]; INC(un); INC(i) END
    END ;
    u[un] := 0X
  END Taie;

  (* codul: litere de masina de scris intre C0 si C1, fara randuri goale la capete *)
  PROCEDURE CodT*(randuri: INTEGER);
    VAR un, a, b, i: INTEGER;
  BEGIN Taie(randuri, un); a := 0; b := un;
    WHILE (a < b) & (u[a] = 0AX) DO INC(a) END ;
    WHILE (b > a) & ((u[b-1] = 0AX) OR (u[b-1] = " ") OR (u[b-1] = 9X)) DO DEC(b) END ;
    C(C0); i := a;
    WHILE i < b DO
      IF u[i] = 9X THEN C(" "); C(" ") ELSE C(u[i]) END ;
      INC(i)
    END ;
    C(C1)
  END CodT;

  PROCEDURE TaieT*(randuri: INTEGER);
    VAR un, i: INTEGER;
  BEGIN Taie(randuri, un); i := 0;
    WHILE i < un DO C(u[i]); INC(i) END
  END TaieT;

  PROCEDURE Cod*(s: ARRAY OF CHAR);
  BEGIN TGol; TS(s); CodT(1000000)
  END Cod;

END Iesire.
